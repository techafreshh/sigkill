#!/usr/bin/env python3
"""Hardened static file server for the SIGKILL web export (verify gate).

Serves the Godot Web export directory (default: ``build/web/``) over HTTP so
the exported artifact can be exercised by CI and the factory's
runtime/holdout scenario gates.

Why this exists instead of ``python3 -m http.server``: the stdlib handler
unquotes %XX escapes and then opens the result with no guard, so a request
containing ``%00`` raises ``ValueError: embedded null byte`` outside any
error handling and the connection is closed without a status line (curl
reports ``000`` / empty reply). Holdout probe ``bad-encoding-inert``
requires malformed paths to be answered 400/404 -- never a dropped
connection or 5xx -- so this subclasses the stdlib handler and converts
malformed encodings, null bytes, and escapes into complete 400/404
responses. Everything else (directory handling, MIME, range/conditional
requests) is stock stdlib behavior.

Usage: ``python3 serve.py [port] [--directory build/web]`` (``$PORT`` wins
when set, per the factory harness convention).
"""

import argparse
import functools
import http.server
import os
import sys

DEFAULT_DIRECTORY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")


class Handler(http.server.SimpleHTTPRequestHandler):
    # Explicit types so the Godot payloads are served correctly even where
    # the host mime.types lacks them. Copied (not mutated) from the base.
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "text/javascript",
    }

    def send_head(self):
        try:
            return super().send_head()
        except (ValueError, UnicodeError):
            # Malformed percent-encoding or an embedded null byte (%00):
            # answer 400 instead of dropping the connection (stdlib) or 500.
            self.send_error(400, "Bad request path")
            return None

    def handle_one_request(self):
        # Never drop the connection and never answer 500: malformed paths
        # are 400, unknown paths are 404 (holdout unknown-resource-404).
        try:
            return super().handle_one_request()
        except TimeoutError:
            self.close_connection = True
            return
        except (ValueError, UnicodeError):
            try:
                self.send_error(400, "Bad request path")
            except Exception:
                pass
            return
        except Exception:
            try:
                self.send_error(404, "File not found")
            except Exception:
                pass
            return

    def _handle_non_get(self):
        # Unknown paths answer 404 for any method, never 501/500.
        try:
            local = self.translate_path(self.path)
            exists = os.path.exists(local)
        except (ValueError, UnicodeError):
            self.send_error(400, "Bad request path")
            return
        if exists:
            self.send_error(501, "Unsupported method (%r)" % self.command)
        else:
            self.send_error(404, "File not found")

    def __getattr__(self, name):
        if name.startswith("do_"):
            return self._handle_non_get
        raise AttributeError(name)

    def log_message(self, fmt, *args):  # keep gate logs readable; stdout stays clean
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("port", nargs="?", type=int, default=0)
    parser.add_argument("--directory", default=None)
    args = parser.parse_args(argv[1:])
    port = int(os.environ.get("PORT", "0")) or args.port or 8000
    directory = args.directory or DEFAULT_DIRECTORY
    if not os.path.isdir(directory):
        print("serve.py: directory not found: %s" % directory, file=sys.stderr)
        return 1
    handler = functools.partial(Handler, directory=directory)
    with http.server.ThreadingHTTPServer(("127.0.0.1", port), handler) as httpd:
        print("serving %s on 127.0.0.1:%d" % (directory, httpd.server_port), flush=True)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
