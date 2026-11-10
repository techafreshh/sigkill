# SIGKILL

A Godot 4 survivors-like: movement-only vs. an off-screen ring swarm — dodge with WASD/arrows while the Bolt auto-fires at the nearest enemy in range.

## Why

SIGKILL has a dual purpose, in this order of weight: **(a) prove the pipeline** — it is built end-to-end by an unattended AI factory ([pi-dark-factory](https://github.com/techafreshh/pi-dark-factory)), as the first *game-shaped* payload that factory has shipped; **(b) ship a fun game** — "one more run" with zero ceremony: open it, dodge, watch the screen fill, die, press R. Scope is cut before the loop is: what is here runs green in CI, everything else waits in [Limitations](#limitations--roadmap).

## Quickstart

Prerequisites: **Godot 4.7** (CI pins `GODOT_VERSION: 4.7.0` and greps `4.7.stable`; `project.godot` targets features `"4.7"`), **export templates** installed (Web preset), **Python 3** (for `serve.py`).

```sh
git clone https://github.com/techafreshh/sigkill.git
cd sigkill
```

Play in the editor:

```sh
godot --path .
# then press Play (main scene is res://main.tscn, viewport 1280x720)
```

Run headless checks (import first — CI enforces import-before-test/export):

```sh
godot --headless --path . --import
godot --headless --path . --script res://tests/test_runner.gd
```

Drive the scripted bots:

```sh
godot --headless --path . --script res://autopilot/autopilot.gd
godot --headless --path . --script res://autopilot/verdict.gd
```

Export for Web, then serve and open it:

```sh
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
python3 serve.py 8000
# open http://127.0.0.1:8000/index.html
```

> [!NOTE]
> `$PORT` wins over the positional port arg (`PORT=8140 python3 serve.py`), per the factory harness convention; default is `8000`. `--directory` overrides the served folder (default `build/web/`).

## Usage

Move with **WASD or arrow keys** (`move_up` / `move_down` / `move_left` / `move_right` — each action carries both bindings). There is **no attack input**: the Bolt child of the Player auto-fires a single non-piercing projectile at the nearest enemy in range every `0.8` s. A camera follows the player over an infinite terminal grid, so the plane looks endless as you move.

The HUD (`StatusLabel`, refreshed every `0.25` s and on every hit/kill) reads:

```text
SIGKILL T+<seconds>s HP=<hp> KILLS=<kills> ALIVE=<alive>
```

Death ends the run (`RUN_END=death game_over=true ERRORS=0 …` on stdout) and the HUD appends:

```text
GAME_OVER death press R to restart
```

Press **R** to reset the run (clock, kills, enemies, projectiles, full HP).

Verification tokens (greppable on stdout):

| Token | Source |
|---|---|
| `TESTS_PASSED=<n>` / exit 0/1 | `tests/test_runner.gd` |
| `AUTOPLAY_VERDICT … ERRORS=0 … FRAMES=…` (60 s wander + measurement phases) | `autopilot/autopilot.gd` |
| `AUTOPLAY_VERDICT_3MIN … ERRORS=0 KILLS>=20 MAX_ALIVE<=300 … RUN_END=alive\|death` | `autopilot/verdict.gd`, `autopilot/bot.gd` |
| `RUN_END=<reason> game_over=true ERRORS=0 …` | `main.gd` `end_run()` |
| `BOLT_FIRE …`, `BOLT_HIT …`, `PLAYER_HIT …`, `ENEMY_POOF XP_PLACEHOLDER kills=…` | combat path diagnostics |
| `SPAWNER_STATUS …` / `SPAWNER_SPAWN …` | `spawner.gd`, only when `verbose = true` (silent by default) |

## Configuration

Tuning lives in `@export` vars on the nodes that read them — no config file, no other env vars. The only environment variable the code reads is `$PORT` (in `serve.py`).

| Setting | File | Default |
|---|---|---|
| `max_entities` (live-enemy cap) | `spawner.gd` | `300` |
| `spawn_interval` (s between batches) | `spawner.gd` | `0.5` |
| `batch_size` (spawns per tick) | `spawner.gd` | `1` |
| `spawn_margin_min` / `spawn_margin_max` (ring offset past viewport half-diagonal) | `spawner.gd` | `50.0` / `150.0` |
| `verbose` (SPAWNER_STATUS/SPAWN logs) | `spawner.gd` | `false` |
| `speed` (px/s) | `player.gd` | `220.0` |
| `acceleration` / `friction` | `player.gd` | `1200.0` / `1400.0` |
| `contact_damage` (per toucher, summed per tick) / `contact_radius` | `player.gd` | `10.0` / `26.0` |
| `shove_strength` / `shove_max_speed` / `shove_acceleration` / `shove_radius` | `player.gd` | `2.0` / `320.0` / `6000.0` / `128.0` |
| `max_hp` | `player/health.gd` | `100.0` |
| `invuln_duration` (i-frames, s) | `player/health.gd` | `0.5` |
| `cooldown` (s between shots) | `weapons/bolt.gd` | `0.8` |
| `attack_range` (px; covers the off-screen spawn ring) | `weapons/bolt.gd` | `950.0` |
| `projectile_speed` / `damage` | `weapons/bolt.gd` | `700.0` / `1` |
| `max_health` | `enemies/chaser.gd` | `3.0` |
| `speed` / `acceleration` / `standoff_distance` | `enemies/chaser.gd` | `140.0` / `600.0` / `28.0` |
| `grid_cell_size` (+ palette, font, glyphs) | `data/theme.tres` (`data/theme.gd`) | `64.0` |
| `hud_refresh_interval` | `main.gd` | `0.25` |
| `PORT` / `[port]` / `--directory` | `serve.py` | `$PORT` wins, else arg, else `8000`; dir defaults to `build/web/` |

Reference values also live in `data/combat.gd` (`PLAYER = {max_hp 100.0, contact_damage 10.0, iframes 0.5, contact_radius 26.0}`) as the data-table surface for balance.

## Architecture

```text
main.tscn / main.gd      run coordinator: physics-clock time, kill counter,
                         run_active/game_over state, StatusLabel paint,
                         R-to-restart (run API: register_kill/get_kills,
                         get_elapsed/is_run_active/is_game_over/get_run_reason,
                         end_run/restart_run/reset_run/get_peak_alive)
├── Ground (world/ground.gd)     infinite camera-snapped terminal grid (z_index -100)
├── Player (player.gd)           CharacterBody2D, "player" group, cursor-block 28x20,
│   │                            WASD/arrows steering, crowd shove, contact damage
│   ├── Camera2D                 follows the player
│   ├── Bolt (weapons/bolt.gd)   auto-weapon + Cooldown timer; projectile built in
│   │                            code (weapons/projectile.gd, "projectiles" group)
│   └── Health (player/health.gd) HP 100, 0.5 s i-frames, health_changed/died signals
├── Spawner (spawner.gd)         off-screen ring spawner, "player"-group lookup,
│                                cap 300, alive_changed push-cache; chaser.tscn factory
└── StatusLabel                  HUD text (see Usage)
data/theme.tres (+ theme.gd)     phosphor-green palette, monospace font, 64 px grid, glyphs
data/combat.gd                   data-only combat tuning numbers
enemies/chaser.gd                steering chaser, 3 HP, "enemies" group
autopilot/                       autopilot.gd (60 s), verdict.gd + bot.gd (3 min)
tests/test_runner.gd             headless suite, TESTS_PASSED token, exit 0/1
serve.py                         hardened static server for build/web (400/404 on bad
                                 paths instead of dropped connections; .wasm/.pck MIME)
export_presets.cfg               "Web" preset → build/web/index.html
.github/workflows/ci.yml         toolchain check → import → reference check →
                                 headless tests → 60 s autoplay → 3 min verdict →
                                 Web export → serve-and-verify over HTTP
```

Related docs: product direction in [.agents/PRDs/PRD.md](.agents/PRDs/PRD.md), decision record in [forge-report.html](forge-report.html), Godot conventions in `.agents/skills/` (curated fundamentals, game-feel, perf, itch-publish notes).

## Limitations / Roadmap

Shipped today is Phase 0+1: move, dodge, kill — player, one chaser type on a ring spawner, one auto-weapon (Bolt), i-frames, cap 300, terminal theme. Everything below is PRD-planned but **not in the build**:

- XP gems, level-up flow (freeze → 1-of-3 upgrade choice), XP bar / timer HUD
- More auto-weapons (Orbit blades, Aura, Railgun) and weapon levels
- Passives (+move speed, +max HP, magnet range, +XP gain, −cooldowns)
- More enemy types (Sprinter, Tank, Elite mini-bosses) and difficulty curve
- Pickups (magnet, heart), run timer / victory screen, death-screen stats
- Audio (impacts, pickups, level-up, death) and game-feel/juice passes
- Public hosting: auto-deploy of the web build to an itch.io staging channel

Until those land, kills log as `ENEMY_POOF XP_PLACEHOLDER` — the hook is there, the economy is not.
