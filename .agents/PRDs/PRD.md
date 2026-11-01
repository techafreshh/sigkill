# PRD — SIGKILL

*One dev vs the swarm. A Godot 4 survivors-like, built by an unattended AI factory.*

---

## 1. Executive Summary

SIGKILL is a Vampire Survivors-style action game: the player controls only movement (WASD/arrows); weapons fire automatically at the nearest threat. The player funnels thousands of swarming enemies into automatic gunfire, collects XP gems from kills, and every level-up freezes the game for a 1-of-3 upgrade choice. A run lasts 15:00 of escalating chaos; HP 0 is death, survival is victory, and both end in a one-click restart — *"one more run" is the product.*

The project has a dual purpose, in this order of weight: **(a) prove the pipeline** — this game is built end-to-end by the pi-dark-factory (unattended lap loop over a GitHub issue backlog), making it the first *game-shaped* payload the factory has shipped; **(b) ship a fun game** — the result must satisfy "fun at minute 10, not just minute 2," verified by structured human playtests at fixed checkpoints. The factory cannot feel fun; the human checkpoints are the only fun-sensor in the loop, so the process is engineered around them (see §12, Slice-Gating).

**MVP goal statement:** a web-hosted, zero-explanation 15-minute survivors-like with 4 auto-weapons, 5 passives, 4 enemy types, a terminal aesthetic, and a restart loop — playable from a public link by someone who has never heard of it.

## 2. Mission

**Product mission:** make "one more run" happen with zero ceremony — open a link, dodge, watch the screen fill, die, restart.

**Core principles:**

1. **Movement is the only input.** No attack button, no aiming, ever. Weapons auto-target.
2. **Machine-checkable done.** Every issue in the backlog closes against an automated gate (headless tests, autoplay verdict, or runtime probes) — never against "it looks done."
3. **Scope cuts beat loop cuts.** When factory-ability and product vision collide, cut product scope (weapons, platforms, content) — never the playtest/deploy loop.
4. **Tuning is data, not code.** Spawn rates, enemy HP, weapon math, and curve multipliers live in data tables so the operator can direct balance changes without code paths changing.
5. **Readability over detail.** Under ~300 concurrent entities, flat high-contrast shapes beat detailed sprites. The terminal aesthetic is a mechanical choice first, a style second.

## 3. Target Users

**Primary persona — the Operator (the project owner).** Never opened Godot; will not write game code. Directs the factory, plays milestone builds, files verdicts, directs tuning. Technical comfort: high (runs a VPS pipeline, comfortable with GitHub, zero game-dev experience). Needs: an always-fresh playable build (staging channel), a cheap feedback ritual (3-field verdict), tuning changes that never require them to touch code. Pain point to design away: playtest procrastination — hence the build cost of playing must be literally zero (auto-deployed staging link).

**Secondary persona — the Friend-Player.** Plays the final web build from a link, on a laptop, in a browser. Technical comfort: whatever a normal person has. Needs: zero explanation — open link → title screen → WASD to move is self-evident. Pain point to design away: any setup step, login, download, or control ambiguity.

## 4. MVP Scope

### In Scope

**Core functionality**
- [ ] Player movement (WASD + arrow keys), HP 100, 0.5s i-frames on enemy contact, death at HP 0
- [ ] Infinite-plane arena (no walls, no boundary collision, camera follows player, scrolling grid ground)
- [ ] 4 auto-weapons × 5 levels each: Bolt (nearest-target projectile), Orbit blades, Aura, Railgun
- [ ] 5 passives: +move speed, +max HP, +pickup magnet range, +XP gain, −weapon cooldowns
- [ ] Level-up flow: XP bar → game freeze → 3-card choice → apply → resume (1-3s of paused time)
- [ ] 4 enemy types: Chaser, Sprinter, Tank, Elite (mini-boss at ~5:00, ~10:00, ~14:00)
- [ ] Pickups: XP gems (all enemies), magnet (vacuums all gems on screen), heart (+30 HP)
- [ ] 15:00 run timer with data-driven difficulty curve; death screen (time/kills/level) and victory screen; one-click restart
- [ ] Terminal aesthetic: monospace font, phosphor palette, glyph/rectangle enemies, kill-text (`SIGSEGV` on elite death) — implemented as a swappable theme resource (font + palette + glyphs)
- [ ] Sound: Kenney audio packs (impacts, pickups, level-up, death) — theme-neutral
- [ ] Juice: screen shake, hit flash, damage numbers

**Technical**
- [ ] Godot 4.x (stable; exact version pinned at the toolchain issue), GDScript only
- [ ] Headless autoplay verdict mode: bot plays ~3 simulated minutes headless, prints machine-readable result; runs in CI on every PR
- [ ] Unit tests on game logic (damage math, XP curve, upgrade application, spawn scaling) runnable headless in CI
- [ ] CI workflow that runs tests + autoplay verdict on every PR (lap 1 deliverable)
- [ ] Web (HTML5) + Windows export from headless Linux CI
- [ ] Auto-deploy of every merged lap's web build to the itch.io staging channel (`butler`)
- [ ] Concurrent-entity cap (~300, configurable) enforced by the spawner

**Deployment**
- [ ] itch.io staging channel (private until M6) → public page at M6

### Out of Scope (v1 non-goals)

- [ ] Meta-progression, persistent unlocks, currency
- [ ] Multiple characters
- [ ] Aiming / attack input of any kind
- [ ] Procedural maps; more than one arena layout
- [ ] Mobile / touch controls; gamepad support
- [ ] Online features, accounts, leaderboards
- [ ] Custom/hand-drawn art; weapon slot limits; upgrade rerolls or bans; weapon evolutions
- [ ] Object pooling (only if profiling at M4 demands it)

## 5. User Stories

1. **As a player, I want to move with WASD while weapons fire on their own,** so that I can focus entirely on the dodge-and-funnel dance. *Example: a pack of Sprinters approaches; I circle strafe and they die inside my Bolt fire without a single click.*
2. **As a player, I want a 1-of-3 upgrade choice every level-up,** so that each run's build emerges from my picks. *Example: at 1:40 I choose between +1 Bolt projectile, Orbit blades, and +10% move speed.*
3. **As a player, I want death and victory screens with my stats and a one-click restart,** so that "one more run" is immediate. *Example: I die at 11:23 / 1,204 kills / level 16; the restart button is under my cursor.*
4. **As a friend-player, I want to open a link and be playing within 5 seconds,** so that no explanation is needed. *Example: title screen → click Start → a one-line "WASD to move" hint → playing.*
5. **As the Operator, I want every merged lap to auto-publish a playable web build to a staging channel,** so that the latest main is always one click away. *Example: lap merges at 14:02; the staging link serves the new build by 14:10.*
6. **As the Operator, I want to file a 3-field verdict (fun yes/no · what felt wrong · one change) per milestone build,** so that the factory gets a fun-signal without me writing a report. *Example: after the M3 build: "yes · level-ups too rare early · double gem XP before 2:00."*
7. **As the Operator, I want to direct balance in words ("harder at minute 8, tanks too spongy"),** so that tuning never requires me to read or edit code. *Example: the next laps change curve-table values; CI re-verifies; the staging build reflects it.*
8. **As the factory (technical), I want CI to run the headless autoplay verdict on every PR,** so that laps merge only when the game demonstrably plays. *Example: a refactor that breaks the spawner fails the verdict (zero kills in 3 simulated minutes) and cannot merge.*

## 6. Core Architecture & Patterns

Single main scene, node-composition over inheritance, everything data-driven.

```
res://
  main.tscn              # run scene: Player, Spawner, Camera, HUD, World
  player/player.tscn     # CharacterBody2D; weapons mounted as child nodes
  weapons/               # bolt.tscn, orbit.tscn, aura.tscn, railgun.tscn — each a child
                         # node with its own cooldown Timer; auto-target nearest enemy
  enemies/               # chaser.tscn, sprinter.tscn, tank.tscn, elite.tscn — simple
                         # steering bodies (move toward player; no pathfinding in v1)
  pickups/               # gem.tscn, magnet.tscn, heart.tscn
  ui/                    # HUD (HP, XP bar, timer, kill count), level-up overlay,
                         # title/death/victory screens
  data/                  # THE tuning surface, all plain data:
                         #   curves.gd      — spawn rate / enemy HP / counts per elapsed minute
                         #   weapons.gd     — per-weapon per-level stats (id, name, icon, effect)
                         #   passives.gd    — per-passive per-level stats
                         #   theme.tres     — terminal aesthetic: font, palette, glyph map
  autoload/              # game state singleton: elapsed time, kills, level, run results
  autopilot/             # headless autoplay bot + verdict reporter (CI entry point)
  tests/                 # headless unit tests (GUT or gdUnit4 — final pick at toolchain issue)
```

**Key patterns and principles:**

- **Upgrades as data.** An upgrade is a dict entry (`id`, `name`, `icon`, `effect`, `level_values[]`) — adding one is a data edit, not a new code path. Weapon/passive effects apply through a small set of shared verbs (add projectile, multiply damage, scale radius, modify cooldown, modify speed).
- **Difficulty curve as data.** Spawner reads `curves.gd` per elapsed minute: spawn interval, batch size, enemy-type mix, HP/damage multipliers. The Elite schedule is a table row, not special-case code.
- **Spawner owns the cap.** Ring spawn just off-screen; refuses to exceed the configurable entity cap (~300).
- **Theme as resource.** All visuals reference `theme.tres` (palette + font + glyphs). Placeholder rectangles *are* the terminal aesthetic primitives from day one — M6 typesets, it does not swap.
- **Headless-first CI.** Any feature must run under `godot --headless` (the autoplay bot and tests are the proof). No feature ships if it can't be exercised headless.
- **Determinism where cheap:** fixed seed available for the autoplay bot and tests so CI verdicts are stable.

## 7. Tools/Features (spec detail)

**Weapons** (all auto-fire; per-level changes are cumulative):

| Weapon | v1 behavior | Level path (1→5) |
|---|---|---|
| Bolt | projectile at nearest enemy, no pierce | +1 projectile · +damage · +fire rate · pierce · +damage/+projectile |
| Orbit blades | N blades circle the player, damage on contact | +1 blade · +radius · +speed · +damage · +1 blade/+damage |
| Aura | ring around player, damage tick on all enemies inside | +radius · +damage/tick · +radius · +damage/tick · +radius |
| Railgun | slow, piercing line shot through all enemies in a direction | +width · +damage · −cooldown · +width/+damage · −cooldown |

**Passives** (5 levels each unless noted): +move speed · +max HP (5 levels) · +pickup magnet range · +XP gain · −weapon cooldowns.

**Upgrade pool rules:** no slot limits (all 4 weapons + 5 passives obtainable per run). Card draws weighted: owned-but-not-maxed upgrades first, new items second. If the entire pool is maxed, the choice includes a filler card (+30 HP). No rerolls, no bans.

**Enemies:** Chaser (walks straight at player) · Sprinter (fast, fragile, arrives in packs) · Tank (slow, bulky, body-blocks bullets — high HP) · Elite (scaled Tank with visible HP bar, spawns ~5:00 / ~10:00 / ~14:00, drops an XP bomb — a large gem cluster vacuumed on pickup). The Elite's fantasy is size + HP bar + `SIGSEGV` kill-text, not new AI.

**Pickups:** XP gems (drop from all enemies) · magnet (rare drop; vacuums every gem on screen) · heart (rare drop; +30 HP, capped at max).

**Difficulty curve (tuning target, not final numbers):** minute 1 feels easy; minute 14 feels desperate; a decent player reaches victory around run 3–5 with no meta-progression. The curve lives entirely in `data/curves.gd` and is tuned against the M5 playtests.

**Level-up flow:** XP bar fills → `get_tree().paused = true` → 3-card overlay → pick → apply → unpause. Target under 3 seconds of player attention per level-up.

## 8. Technology Stack

- **Engine:** Godot **4.7-stable** — matching the factory's prebaked `godot-base` snapshot (editor binary + web export templates included). Headless Web + Windows exports from Linux. The web export preset is named **`Web`** and outputs to `build/web/` — a pinned contract, because the factory's verify gate serves that directory.
- **Language:** GDScript only. No C#, no GDExtension, no addons except the test framework.
- **Testing:** headless-runnable GDScript test framework (gdUnit4 suggested; final pick at the toolchain issue — the constraint is *runs in headless CI*, not the name).
- **Art/audio:** one free monospace font (e.g. a terminal-standard like JetBrains Mono or VT323); Kenney audio packs (CC0). No sprite assets.
- **Deployment:** itch.io + `butler` CLI from CI; staging channel until M6, then public page.
- **CI:** GitHub Actions (bootstrapped by the factory as lap 1): runs unit tests + autoplay verdict on every PR; on merge, headless-exports Web build and pushes to staging.

## 9. Security & Configuration

- **No auth, no network in-game.** The game makes no requests; there is nothing to secure at runtime. (Out of scope: accounts, telemetry, leaderboards.)
- **Secrets:** the itch.io `butler` API key lives only in GitHub Actions secrets and the operator's machine — never in the repo, never in PRD or issues. No other secrets exist.
- **Configuration:** Godot project settings carry input map (WASD + arrows → `move_*` actions), window settings (fixed base resolution, canvas_items stretch), and the entity cap. All balance numbers live in `data/` — the operator-facing config surface.
- **Deployment considerations:** staging channel is private (unlisted) until M6; itch.io page goes public only on the operator's explicit action.

## 10. Verification Contract (replaces API spec)

No HTTP API exists in the product; the factory's scenario gates wrap the **web export artifact**. Split of machine gates:

**CI (required check on every PR) — the meaningful gate:**
- Unit tests (headless): damage math, XP/level thresholds, upgrade application, curve tables well-formed, pool-draw rules.
- **Autoplay verdict** (headless, ~3 simulated minutes, fixed seed, scripted wander pattern). Verdict JSON asserts all of:
  - zero script errors / zero push_errors;
  - kills > threshold;
  - XP accrued and ≥ 1 level-up fired;
  - entity count never exceeds the cap;
  - run terminates cleanly (bot death or timer end), results recorded.
- A PR that fails any of these cannot merge.

**Runtime scenario (`runtime.json`, verify gate):**
- `start`: standard static file server over the exported web build (`python3 -m http.server $PORT` in the export directory — a standard server, never a bespoke supervisor).
- `readiness_path`: `/index.html`.
- Probes: `status:200` on `/index.html`; `status:200` on the `.wasm` and `.pck` payload paths; `body_contains:` expected shell markers.

**Holdout scenario (`holdout.json`):**
- Unknown paths return 404, never 5xx (`status_in:200,404`); malformed subpath probes are inert; the served `index.html` contains the expected boot markers.

## 11. Success Criteria

**MVP success definition — all three:**
- [ ] **Fun at minute 10, not just minute 2.** Verified by the operator's two M5 structured playtests, not by machine gates.
- [ ] **A friend plays the public web build from a link with zero explanation.** Verified at M6 with 3 friends.
- [ ] **After dying, the operator immediately clicks restart** — the loop is frictionless. (Self-observation at any checkpoint; if the operator ever *doesn't* want the restart click, the game has a problem.)

**Functional requirements:**
- [ ] Full 15:00 run is playable end-to-end on the web build (chrome desktop) and Windows
- [ ] All 4 weapons × 5 levels, 5 passives reachable in one run
- [ ] Elite appears at the scheduled marks and drops an XP bomb
- [ ] Death and victory screens show time / kills / level; restart is one click
- [ ] Entity cap respected at all times; minute-14 scene stays playable (no frame-time collapse on the web build)

**Quality indicators:** CI green on every merged lap; autoplay verdict stable (fixed-seed); zero script errors in a full simulated run; staging build freshness < 30 min after merge.

**Experience goals:** minute 1 easy, minute 14 desperate, victory ≈ run 3–5 for a decent player.

## 12. Implementation Phases

Wall-clock time is governed by factory ticks, not human hours; phases are sized in **issue clusters**. **Slice-gating rule:** the operator (or pilot session) slices only the next cluster's issues into the backlog after filing the previous build's 3-field playtest verdict. The PRD contains all clusters up front; slicing is operator-paced via the factory's backlog verb.

**Phase 0 — Walking skeleton + toolchain** *(before any gameplay issue)*
- Goal: the pipeline exists and proves itself on a stub.
- Deliverables: [ ] CI workflow (lap-1 deliverable) running headless unit-test skeleton on every PR · [ ] toolchain verified in-lane: lap 1 confirms `godot --version` reports 4.7-stable and the web export templates resolve (factory `godot-base` snapshot, prebaked 2026-11-01 — no install issue needed) · [ ] stub web build (empty Godot project) auto-exported on merge and pushed to the itch.io staging channel · [ ] autoplay-verdict skeleton wired into CI (asserts: boots, runs 60 simulated seconds, zero errors)
- Validation: a merged PR visibly updates the staging build; CI red/green demonstrably gates a PR.

**Phase 1 — Core loop (brief M1+M2): move, dodge, kill**
- Goal: the game exists — the second-to-second loop is alive.
- Deliverables: [ ] player movement + camera + infinite grid ground · [ ] Chaser enemy + ring spawner · [ ] Bolt auto-fire · damage/death (enemy + player) · i-frames · [ ] entity cap · [ ] terminal theme resource (palette/font/glyphs) from day one
- Validation: CI green incl. autoplay (kills > threshold) → **Operator checkpoint 1** (glance, ~2 min) then **checkpoint 2** (15 min: "is the core loop alive?") → verdict gates Phase 2 slicing.

**Phase 2 — Meta loop (brief M3): gems + level-up**
- Goal: the minute-to-minute loop exists.
- Deliverables: [ ] XP gems + magnet pickup + heart · [ ] XP bar · [ ] level-up freeze + 3-card overlay + upgrade application · [ ] upgrade pool rules (weighting, filler)
- Validation: autoplay asserts ≥1 level-up fires → **Operator checkpoint 3** (15 min: level-up rhythm — the most important single test) → verdict gates Phase 3.

**Phase 3 — Build variety (brief M4): all weapons + passives**
- Goal: builds differ; nothing feels dead.
- Deliverables: [ ] Orbit blades, Aura, Railgun (data-driven) · [ ] 5 passives · [ ] full pool integration
- Validation: autoplay runs with randomized pick sequences across all weapons; unit tests cover per-level math → **Operator checkpoint 4** (15 min: which upgrades feel dead) → verdict gates Phase 4.

**Phase 4 — The run (brief M5): 15 minutes, elite, endings**
- Goal: the full run arc exists and is tunable.
- Deliverables: [ ] `curves.gd` difficulty tables (spawn rate/mix/HP per minute) · [ ] Sprinter + Tank · [ ] Elite + XP bomb · [ ] death/victory screens + one-click restart · [ ] perf pass at minute-14 scale
- Validation: autoplay completes a fast-forwarded full run cleanly; cap respected → **Operator checkpoints 5+6** (2 × 20 min: the two full-run tuning passes; target victory ≈ run 3–5) → verdicts gate Phase 5.

**Phase 5 — Ship (brief M6): juice + sound + public**
- Goal: it looks, sounds, and spreads like a product.
- Deliverables: [ ] screen shake, hit flash, damage numbers, kill-text · [ ] terminal typesetting pass (all screens) · [ ] Kenney audio integrated · [ ] Windows export verified · [ ] itch.io page made public · [ ] friend playtest (3 friends, zero-explanation criterion)
- Validation: **Operator checkpoint 7** (friend test) → PRD's success criteria checked or the failures become the next sliced issues.

## 13. Future Considerations (post-MVP)

- Meta-progression (persistent unlocks, currency) — the classic survivors-like retention layer
- Weapon evolutions (weapon + passive combos at max level)
- Second character with a different starting weapon / stat skew
- Gamepad support; Steam export
- Second arena theme (still no procedural maps) — e.g. a "kernel panic" palette swap as data
- Upgrades: slot limits, rerolls, bans — the build-identity layer

## 14. Risks & Mitigations

1. **Verify-gate theater** — the factory merges laps on green checks that prove nothing about play. *Mitigation:* autoplay verdict asserts outcomes (kills, level-ups, cap), not just absence of errors; slice-gating means no cluster builds on an unplayed one; verdicts are cheap (3 fields) so they actually happen.
2. **Web export performance** — ~300 entities + bullets on HTML5 may not hold 60fps. *Mitigation:* entity cap is configurable and can be lowered on web export; perf is a named deliverable in Phase 4, before art/juice lands; profiling before pooling (guardrail from the brief).
3. **Toolchain drift or gaps in the build environment.** *Mitigation:* largely closed — the factory's `godot-base` snapshot (Godot 4.7-stable + web export templates) was prebaked 2026-11-01 for this lane, and lap 1 re-verifies it in-lane; runtime scenarios are `--test`-ed before the first lap; if the base is ever re-baked, re-verify the Godot version before new laps claim.
4. **Fun never arrives** (the design risk every survivors-like carries). *Mitigation:* earliest possible core-loop playtest (Phase 1 checkpoint, ~2 checkpoints in); ruling: cut product scope, never cut the loop — if minute 2 isn't fun, the fix is core-loop iteration, not content.
5. **Scope creep via issue drift** (the slicer slices what the PRD says). *Mitigation:* non-goals list is explicit and checked into this PRD; new ideas during the run go to §13, not the backlog; slice-gating gives the operator a natural checkpoint to refuse drift.

## 15. Appendix

**Operator checklist (never becomes a factory issue):**
- [x] Create GitHub repo `techafreshh/sigkill`, push this PRD to `.agents/PRDs/PRD.md` (done 2026-11-01)
- [x] Factory onboarding (done 2026-11-01): slug `sigkill`, scenario ports 8140/8141, env.mode **instabox** on the `godot-base` snapshot, models `meta/muse-spark-1.3-contributor` (plan/implement/review **xhigh**, default high), squash-merge, `required_checks ["*"]`, 3 attempts
- [ ] Create itch.io account + project page; generate `butler` API key; add to GitHub Actions secrets (needed by the walking-skeleton lap)
- [ ] Slice Phase 0 + Phase 1 clusters only; hold later clusters until verdicts

**Slice-gating recap:** playtest verdicts (3 fields: fun yes/no · what felt wrong · one change) are the throttle. No cluster's issues enter the backlog until the previous build's verdict is filed.

**Related documents:** this PRD is distilled from the forge session (see `forge-report.html` at the repo root for the decision record).

**Agent skills:** `.agents/skills/` carries 14 skills curated from `gamedev-skills/awesome-gamedev-agent-skills` — Godot fundamentals (`godot-gdscript`, `-nodes-scenes`, `-signals-groups`, `-resources`, `-2d-movement`, `-physics`, `-ui-control`, `-audio`, `-shaders`, `-export`, `-gdscript-headless-testing`) plus `game-feel`, `performance-optimization`, `itch-publish`. Committed before lap 1 so lap agents and local sessions share the same Godot lore. Deliberately NOT the full 69-skill collection: other engines' skills and genre/feature skills matching v1 non-goals (`save-systems`, `procedural-gen`, `level-design`, `dialogue-systems`) are excluded to protect the scope line and lap context budget. Cross-references inside skills to uninstalled siblings are harmless dead ends. Whether the factory's lap agents load repo-level skills is verified empirically after lap 1 (the Stage 2 `pi` block wires factory-shipped skills per-lap; repo-level loading is not config-controlled).

**Forge decisions baked into this PRD:** factory is the dev · dual purpose B+A (prove pipeline, ship fun) · cut scope, never the loop · staging-on-merge + slice-gating + 7 weighted checkpoints · infinite plane · terminal aesthetic (theme-as-resource) · itch.io staging = final delivery · autoplay gate in Phase 0–1 · tuning-as-data · victory ≈ run 3–5 target · no slot limits / no rerolls · Elite = scaled Tank, no new AI.
