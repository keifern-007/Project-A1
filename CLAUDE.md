# CLAUDE.md — ProjectA1 ("Get Good")

This file tells Claude how to work on this project. Read it fully before every session.
The source of truth for design is `GameDevDocumentProjectA1.docx` (Kyle DV). This file turns it into rules and a roadmap.

---

## 1. What we're building

A **co-op roguelike** in **Godot 4 (GDScript)** with a **semi-3D retro look**.

**Core loop (never lose sight of this):**
> Pick a character → pick a map → pick an objective (Horde / Boss / Gather) → survive & earn rewards → spend rewards on skills, gear, cosmetics → play harder missions → repeat.

**Pillars**
1. **Earned rewards** — learning a mechanic should visibly make the next run better.
2. **Build variety** — characters + skills + passives + gear, with **positive/negative trade-offs** (pick a strength, accept a weakness).
3. **Replayability** — map biomes change enemies (snow, desert/mummy, etc.) and reward elemental counter-building (fire vs. cold).
4. **Charm** — light-hearted tone with dark undertones; bright gathering missions, stormy boss missions.
5. **Accessible to everyone** — accessibility options are features, not afterthoughts.

**Game flow (team design):** Title screen → **Camp**, a *walkable* 3D hub. All heroes live in the camp, each in their own area; you pick who to play there (see Phase 4 character decisions). Walk up to stations and press interact: Mission Board (choose a mission), Forge (crafting), Skill Shrine (spend skill points), Gear Rack (loadout), Stash, later NPCs/quests → run → results → back to Camp as the same hero. New camp features = new station + `Interactable` with an `action`, handled in `hub.gd`.

### Progression & equipment design (Albion Online-inspired — team decision)
Aim: skill tree and loadout as deep as Albion Online. **Skill points (team decision, replaces auto-levelling tracks):** every activity (gathering, crafting, fighting) gives **Rank XP**; each Rank level-up gives `Progression.SKILL_POINTS_PER_RANK` (3) skill points; you spend them at the Skill Shrine, 1 point = +1 level in the track of your choice. No respec for now. Tracks:
- **Gathering** (per material type, e.g. Herbalism): higher level → can gather higher-tier nodes.
- **Crafting** (per item category, e.g. axe, shield, leaf armor): higher level → can craft higher-tier items.
- **Mastery** (per weapon/armor category): higher level → can *use* higher-tier gear.
- **Rank** = overall account level from ALL XP earned: grants skill points and unlocks content (maps, story, enemies, side quests…).
- Shown/managed at the camp's **Skill Shrine**.

**Loadout: 8 slots** — Main hand, Off hand, Helmet, Chest, Waist, Boots, Trinket, Consumable.
Hand rules: two-handed weapons take both hands; off-hand items (shield, book, torch…) only go off-hand; one-handed main-hand weapons can also go off-hand (dual-wield, wand + sword, etc.).
Every `ItemData` has `tier` (T1, T2…) and `category` (mastery/crafting track). Tier requirement = track level from `Progression.TIER_LEVELS` (T1: 1, T2: 3, T3: 6). Items are **stackable** (craft many copies — crafting XP needs repetition; two copies = dual-wield the same weapon). Keep tiers small (T1–T3) until the vertical slice, then expand.

**References from the GDD:** Dragon's Crown (character select), Albion Online (equipment/skill display), Left 4 Dead (hordes), Dark Souls (bosses), Monster Hunter (farming), Dragon Quest (NPC quests), Final Fantasy (enemy/map variety).

**Platforms:** PC first — Steam and itch.io. Consoles only if opportunity appears; don't design for them now.

### Open decisions (ask Kyle before locking these in)
- **Setting:** fantasy *or* sci-fi. Default to **fantasy** for placeholders until decided. Keep names/art swappable.
- **Camera:** top-down/isometric 3D vs. side-on 2.5D brawler (Dragon's Crown style). Default: **isometric 3D**.
- **Multiplayer size:** default **1–4 players, online co-op**.
- **Loot on defeat:** DECIDED for now — keep everything (`SaveManager.DEFEAT_KEEP_FRACTION = 1.0`). May change; it's one constant.

### Phase 4 character decisions (team, decided — alternatives kept in case of a change of mind)
- **Skill source — DECIDED: Both.** Character gives a unique passive + 2 signature skills (keys 1–2); the main-hand weapon gives the other 2 skills (keys 3–4), so gear changes your kit.
  - Alt A *Character only*: 4 fixed skills + passive per character; gear is stats only (simpler, classic brawler).
  - Alt B *Weapon only*: characters differ by passive + base stats; all 4 skills come from weapons (pure Albion).
- **Progression sharing — DECIDED: Shared account.** Materials, items, Rank, skill points and track levels are shared; only the equipped loadout is per character (`profile.loadouts[character_id]`).
  - Alt *Per-character levels*: materials/items shared, but each character has its own Rank, skill points and track levels (more replay per character, more grind). Switching = move `rank_xp`, `skill_points`, `track_levels` under `profile.characters[id]` with a save migration.
- **Select flow — DECIDED (revised): heroes live in the camp.** Title screen (Start/Quit) → camp. Each hero is spawned in their own themed area (`HeroArea`: Brawler left = training dummy, Warden middle = shield wall + banner, Mystic right = rune circle). First visit: nobody is controlled; the camera glides to the browsed hero and their card opens on the side away from them (left/middle area → card on the right, right area → card on the left); browse with Left/Right or click a hero; 'Play as' takes control. Later: walk up to an NPC hero and interact (or click them) → card → switch; the old hero becomes an NPC and walks home (pops home if stuck 2 s).
  - Earlier version (replaced): a separate Dragon's Crown-style select screen + Hero Tent station. Other alts: start straight in camp without a title screen; old hero stays where you left it, or a fade with everyone back home; simple marked spots instead of themed areas.
- **Roster — DECIDED: Brawler / Warden / Mystic** (placeholder fantasy names, rename freely in the .tres + translations).
  - Brawler: fast DPS — low HP, high attack, fast move + dodge. Warden: defender/support — high HP + defense, slow. Mystic: ranged caster — low HP, attacks from range.
  - Alt: any roster the team describes (name, role, strengths, weaknesses) — adding one = a new `CharacterData` .tres.

---

## 2. How to work with me (vibe-coding rules)

I'm learning as I go. Optimize for **a game that runs after every change**.

- **Small steps.** One feature per request. After each step, tell me exactly how to test it in the editor (which scene to run, what to press, what I should see).
- **Always runnable.** Never leave the project in a broken state. If a change spans many files, finish it or revert it.
- **Explain briefly.** 2–4 sentences on *what* you did and *why*. Teach me the Godot concept if it's new (signals, Resources, autoloads, etc.).
- **Don't invent scope.** Stick to the current roadmap phase. If you think something from a later phase is needed now, say so and ask.
- **Ask before:** adding plugins/addons, changing the folder structure, renaming autoloads, or rewriting a system that already works.
- **Say when you're unsure** about a Godot API. Godot 3 and Godot 4 differ a lot — always use **Godot 4** syntax (`CharacterBody3D`, `@export`, `@onready`, `signal.emit()`, `await`, typed arrays).
- **Git:** remind me to commit at the end of every working milestone with a suggested commit message.
- **If I paste an error,** find the root cause, fix it, and tell me what caused it in one line.

---

## 3. Tech rules

### Engine & language
- Latest stable **Godot 4.x**, **GDScript** only (no C#), **Forward+** or **Mobile** renderer (Compatibility if itch web build is wanted later).
- **Static typing everywhere:** `var hp: int = 100`, `func take_damage(amount: int) -> void:`.
- `snake_case` for files, functions, variables. `PascalCase` for `class_name` and node names. `SCREAMING_CASE` for constants.

### Architecture
- **Data-driven with Resources.** Characters, enemies, skills, items, materials, maps, objectives, and cosmetics are `Resource` subclasses saved as `.tres` files. Adding content = adding a `.tres`, not writing code.
- **Composition over inheritance.** Reusable components as child nodes: `HealthComponent`, `HitboxComponent`, `HurtboxComponent`, `StatsComponent`, `StatusEffectComponent`.
- **Signals up, calls down.** Children emit signals; parents call methods on children. No reaching across the tree with long `get_node("../../..")` paths.
- **Autoloads (keep these few):**
  - `GameState` — current run data (character, map, objective, run rewards).
  - `SaveManager` — meta-progression saving/loading (`user://save.json` or `ConfigFile`, versioned).
  - `Settings` — options + accessibility flags, persisted to `user://settings.cfg`.
  - `EventBus` — global signals only (e.g. `enemy_killed`, `run_ended`).
  - `Net` — added in Phase 5.
- **Scripts stay small** (~200 lines). Split when bigger.
- **Multiplayer-friendly from day one** (even before networking exists):
  - Separate **input** from **logic** — the player reads from an input source that could later be a network peer.
  - Gameplay outcomes (damage, drops, deaths) happen in one place, so they can become **host-authoritative** later.
  - Use `randomize`-free seeded RNG (`RandomNumberGenerator` with a run seed) so runs can sync.

### Accessibility & text — from day one
- **All player-facing text goes through `tr()`** with keys (`"UI_START"`), stored in a translation CSV. No hard-coded strings.
- **Never use color alone** to convey info (add icons/shapes/text).
- **Flashes and screen shake** go through a single helper that respects `Settings.reduce_flashing` and `Settings.screen_shake`.
- **Spider-type enemies** have an `is_arachnid` flag and an alternate model/sprite for the arachnophobia option.

### Folder structure
```
res://
  autoload/          # GameState, SaveManager, Settings, EventBus, Net
  scenes/
	main/            # main menu, character select, hub, run end screen
	player/
	enemies/
	bosses/
	maps/
	ui/              # HUD, menus, options
	vfx/
  components/        # Health, Hitbox, Hurtbox, Stats, StatusEffect...
  resources/
	characters/  enemies/  skills/  items/  materials/  maps/  objectives/  cosmetics/
  scripts/           # class_name Resource definitions + shared helpers
  shaders/           # pixelation, palette, colorblind filters
  assets/
	models/  sprites/  textures/  audio/music/  audio/sfx/  fonts/
  localization/      # translations.csv
```

### Semi-3D retro look (target technique)
- Low-poly 3D world rendered into a **low-resolution `SubViewport`** (e.g. 480×270 or 640×360) and scaled up with **nearest-neighbor** filtering.
- Characters/enemies: either low-poly models or **billboarded `Sprite3D`** sprites.
- Optional extras later: limited palette shader, vertex snapping (PS1 wobble), dithering.
- Lighting/weather per map sets the mood: bright for gathering, dark skies + rain for bosses.

---

## 4. Roadmap

Each phase ends with a **playable milestone**. Don't start the next phase until the current milestone works. Rough timeline assumes the GDD's 1–2 years, part-time.

### Phase 0 — Setup (week 1)
- [x] Godot project, folder structure, Git repo + `.gitignore` for Godot (`.godot/`).
- [x] Autoload stubs: `GameState`, `SaveManager`, `Settings`, `EventBus`.
- [x] Input map: move, aim, attack, skill_1–4, dodge, interact, pause (keyboard + gamepad).
- [x] Retro rendering pipeline: low-res `SubViewport` + upscale.
- [x] `localization/translations.csv` with first keys.
- **Milestone:** a grey box level renders with the retro pixel look.

### Phase 1 — Core combat (weeks 2–6)
- [x] Player: `CharacterBody3D` movement, camera follow, dodge with i-frames.
- [x] Components: Health, Hitbox, Hurtbox, Stats.
- [x] Basic attack + 1 active skill.
- [x] One enemy type (chase + melee) with simple state machine (idle/chase/attack/dead).
- [x] Spawner that spawns enemies in waves.
- [x] Minimal HUD: HP, skill cooldown, timer, kill count.
- [x] Death → game over → restart.
- **Milestone:** "Survive 3 minutes" is fun for 3 minutes. **Tune game-feel here** (hit stop, knockback, sound) before adding more.

### Phase 2 — The run (weeks 7–12)
- [x] `ObjectiveData` Resource with three types:
  - [x] **Horde:** survive N waves with rising difficulty.
  - [x] **Boss:** complete objectives → boss spawns → boss-exclusive drops.
  - [x] **Gather:** collect X materials from nodes while enemies harass you.
- [x] Mission select screen (map + objective).
- [x] In-run rewards: XP/levels, drops (materials, items, boosters). *(items = equipment, deferred to Phase 3 with `ItemData`/crafting)*
- [x] First boss with 2–3 attack patterns and telegraphs. *(Ogre, Dark Souls-style placeholder)*
- [x] Run end screen: what you earned.
- **Milestone:** a complete run from mission select → objective → results. ✅

### Phase 3 — Meta-progression (weeks 13–20)
- [x] `SaveManager`: persistent profile (unlocks, materials, currency, skill points), save version number.
- [x] Hub / camp scene between runs. *(walkable 3D camp: Mission Board, Forge, Gear Rack, Stash; Skill Shrine)*
- [x] **Crafting:** materials → equipment (`ItemData` with stat modifiers). 
- [x] **Skill Shrine progression:** tracks — Gathering per material, Crafting per category, Mastery per weapon/armor category — levelled with skill points earned from Rank (account level).
- [x] **Tiers & gating:** gather level → node tier, crafting level → recipe tier, mastery → equippable tier, Rank → unlocked maps/missions/content.
- [x] **Consumable slot:** craft potions, equip one, use it in runs.
- [x] ~~Skills in the loadout~~ — moved to Phase 4 (weapon skills = keys 3–4, see Phase 4 character decisions).
- Trade-offs live in gear (negative stats) for now; revisit trade-off nodes after the Shrine exists.
- [x] Equipment loadout screen (Albion-style paper doll, 8 slots, hand rules) at the Gear Rack. *(order swapped with the skill tree by team decision so crafted gear matters first)*
- [x] Challenge missions: optional harder variants with better rewards (casuals can ignore).
- **Milestone:** a second run feels noticeably stronger because of the first. ✅ (15 runs, Rank 19, crafted gear)

### Phase 4 — Content & variety (weeks 21–32)
- [x] **Character select** (Dragon's Crown-style) with 3 starting characters: Brawler (DPS), Warden (defender), Mystic (ranged caster). Per-character loadout. Heroes live in the camp in their own areas; pick/switch there via hero cards.
- [x] Unique passive per character: Brawler **Bloodrush** (kills stack +4% dmg, 4 s, max 5), Warden **Bulwark** (-20% damage taken, no knockback), Mystic **Attunement** (skill cooldowns +30% faster).
- [x] Skills step A: 4-slot loadout (keys 1–2 = character signatures, keys 3–4 = main-hand weapon skills, else unarmed), projectiles, Mystic Magic Bolt basic attack, 6 signatures — Brawler Dash Strike + Whirlwind, Warden Shield Bash + Iron Guard, Mystic Arcane Barrage + Blink.
- [x] Skills step B: weapon skills per item (`ItemData.skills`) — Goblin Hatchet: Cleave + Hatchet Throw; Tusk Cleaver: Cleave + Ground Slam; Goblin Shiv: Flurry + Fan of Knives; Moonleaf Wand: Moonleaf Bolt + Healing Bloom; unarmed: Haymaker + Ground Slam.
- [x] Each character: its own talent tree (6 talents, 3 tiers, tier-3 'choose one' trade-off capstone), bought with the shared skill points at the Skill Shrine's '<Hero> Talents' tab.	
- [x] **Element/status system:** Fire = Burn, Ice = Chill/Freeze, Poison = stacking DoT; per-enemy weaknesses/resistances; status text + symbols above enemies.
- [x] **Biome variants:** `EnemyData` has per-biome variants (Snow = Frost, Desert = Mummified; base types = Forest/Training Grounds), different resistances and map-exclusive materials.
- [ ] 3 maps with distinct mood, lighting and weather.
- [ ] 5–8 enemy types, 3 bosses.
- **Milestone:** vertical slice — 3 characters × 3 maps × 3 objectives. **Share it on itch.io for feedback.**

### Phase 5 — Co-op multiplayer (weeks 33–42)
- [ ] `Net` autoload using Godot high-level multiplayer (`ENetMultiplayerPeer`) for LAN/direct IP first.
- [ ] Host-authoritative: host runs enemies, damage and drops; clients send input.
- [ ] `MultiplayerSpawner` / `MultiplayerSynchronizer` for players, enemies, projectiles, pickups.
- [ ] Lobby: host/join, ready-up, character select per player.
- [ ] Shared vs. personal loot rules; revive downed teammates.
- [ ] Later: Steam lobbies via **GodotSteam** (ask before adding).
- **Milestone:** two players finish a boss run together without desync.
- ⚠️ Expect this phase to surface bugs from earlier systems. That's normal.

### Phase 6 — Options & accessibility (weeks 43–48)
- [ ] Options menu: audio buses (master/music/sfx), video, controls rebinding.
- [ ] **Multi-language:** finish translation CSV, language selector, font that supports needed scripts.
- [ ] **Customizable HUD:** move/scale/hide elements, saved in `Settings`.
- [ ] **Arachnophobia mode:** swaps all `is_arachnid` visuals.
- [ ] **Epilepsy/photosensitivity mode:** reduces flashes, strobe, screen shake.
- [ ] **Colorblind modes:** filter shader (protanopia/deuteranopia/tritanopia) + icon redundancy check.
- **Milestone:** a friend who's never played can configure the game comfortably.

### Phase 7 — Story, quests & cosmetics (weeks 49–60)
- [ ] NPCs in the hub with simple dialogue system (Resource-based, `tr()` keys).
- [ ] Character quests that unlock skills.
- [ ] Short campaign tying characters together; humor + dark undertones.
- [ ] Cosmetics: armor/skins unlocked via missions & challenges, cosmetic-only.
- **Milestone:** players have a reason to care about at least one character.

### Phase 8 — Polish & release (weeks 61+)
- [ ] Music (orchestral for fantasy / electronic for sci-fi), calm tracks, unique boss themes.
- [ ] SFX pass, VFX pass, juice.
- [ ] Balancing pass (spreadsheet of stats; trade-offs feel fair).
- [ ] Performance: object pooling for enemies/projectiles, profile with 4 players + big hordes.
- [ ] Steam page, itch page, trailer, demo.
- [ ] Export presets: Windows (+ Linux/macOS if easy).
- **Milestone:** ship it. 🎉

---

## 5. Scope guardrails

The GDD itself names the risks: limited time, personal life, inexperience. So:
- **Vertical slice first (end of Phase 4)**, then decide what to cut.
- If a phase drags past 2× its estimate, stop and cut features rather than push through.
- **Cut order if needed:** campaign length → number of maps → number of characters → cosmetics. Never cut core-loop quality or accessibility basics.
- Placeholder art (capsules, cubes, free CC0 assets) is fine until Phase 8. Fun first, pretty later.

---

## 6. Current status

> Update this section as you go so Claude knows where we are.

- **Current phase:** 4 (content & variety) — Phase 3 complete
- **Setting decided:** Medieval Fantasy
- **Camera decided:** Over-the-Shoulder 3rd Person
- **Last thing done:** Phase 1 complete: player movement/camera/dodge; Stats/Health/Hitbox/Hurtbox components, damage math in `scripts/combat.gd`; melee attack (`MeleeAttackComponent`) + skills (`SkillCasterComponent`, `SkillData` .tres in `resources/skills/`, effects extend `SkillEffect`, first skill = Ground Slam). Aim: mouse (RetroView forwards mouse motion into the SubViewport) or right stick, else facing. First enemy: Goblin (`scenes/enemies/goblin.tscn`, `MeleeEnemy` enum state machine IDLE/CHASE/ATTACK/DEAD, stats from `EnemyData` .tres in `resources/enemies/`, targets nearest node in group `players`, lean-back telegraph). `GameState.kills` counts `EventBus.enemy_killed`. Physics layers: 1 world, 2 player, 3 enemy, 4 hits_player, 5 hits_enemy (hitbox LAYER = who it hurts, hurtbox MASK = what hurts it). Waves: `components/wave_spawner.gd` (`WaveSpawner`, spawns at its `Marker3D` children using `GameState.rng`; sets `hunt_from_start` on spawned enemies) in the grey box. `GameState.start_run()` is temporarily called from `retro_view.gd` until mission select exists. HUD: `scenes/ui/hud.tscn` (+ `skill_slot.tscn`) in RetroView's full-res `UI` CanvasLayer; RetroView calls `hud.bind_player()`. Timer = `GameState.run_time` (ticks while `run_active`). Waves reach the HUD via `EventBus.wave_started`. Death: player tips over + `EventBus.player_died`; RetroView ends the run when no player is alive, pauses after 1.2 s and shows `scenes/ui/game_over.tscn` (process_mode Always); Restart = `reload_current_scene()`. `GameState.wave` tracks wave reached. Game feel: `scripts/game_feel.gd` (`GameFeel.hit_stop()` / `GameFeel.shake()` — the ONLY way to do hit stop/shake; respects `Settings.screen_shake` + `reduce_flashing`), camera shake in `CameraFollow` via `EventBus.screen_shake_requested`, knockback via `HitboxComponent.knockback` + `EnemyData.knockback_resistance`. Test scripts run with `-s` can't reference autoload names or classes that use them — use `root.get_node("GameState")` and untyped access. Engine: Godot 4.7.2 (Steam). Phase 2 step 1: `ObjectiveData` (`scripts/objective_data.gd`, .tres in `resources/objectives/`) + runners in `scenes/main/objectives/` (`Objective.create(data)` factory, `HordeObjective` configures/starts the map's `WaveSpawner` (group `wave_spawners`, `max_waves`, `health_growth_per_wave`)). Progress → HUD via `EventBus.objective_progress`. RetroView uses `GameState.objective` or its `default_objective` (horde_standard.tres: 5 waves) and shows the run end screen for victory or defeat (`GameOverScreen.show_results(victory, ...)`). Phase 2 step 2: Gather objective — `MaterialData` (`resources/materials/moonleaf.tres`), `scenes/maps/gather_node.tscn` (`GatherNode`: hold interact to harvest, emits `EventBus.material_gathered`), `GatherObjective` spawns nodes at map Marker3Ds in group `gather_points` + endless harassment waves; `Objective._setup_spawner()` shared by objectives; gathered materials land in `GameState.run_rewards[\"materials\"]`. `InputHints.key_for(action)` for on-screen key prompts. To play a Gather run before mission select exists: set RetroView's `default_objective` to `gather_moonleaf.tres`. Phase 2 step 3: Ogre boss (`scenes/bosses/ogre.tscn`, `OgreBoss` state machine INTRO/CHASE/WINDUP/STRIKE/RECOVER/DEAD; attacks are `BossAttack` child nodes with telegraph marker + hitbox + timings: Smash (delayed overhead), Sweep, Leap (ranged gap-closer, top_level landing ring); slow turning, no flinch, enrage <50% HP = ×1.35 speed + Sweep→Smash combo; placeholder tweens in `OgreAnimator`). `BossObjective`: kill `kills_before_boss` → spawner stops → boss at map Marker3D group `boss_spawns` → `EventBus.boss_defeated` → `boss_drop` (Ogre Tusk). Boss HP bar `scenes/ui/boss_bar.tscn` (listens `EventBus.boss_spawned/boss_defeated`). Shared `Targeting` helper (`scripts/targeting.gd`). `EventBus.material_gathered` renamed `material_obtained`. To play: set RetroView `default_objective` to `boss_ogre.tres`. Phase 2 step 4: mission select is the main scene (`scenes/main/mission_select.tscn`: lists `MapData` + `ObjectiveData` resources set in its Inspector, writes `GameState.map/objective`, then loads the run scene). `MapData` (`scripts/map_data.gd`, `resources/maps/greybox.tres` = Training Grounds). The run scene (`retro_view.tscn`) no longer contains a map: it instantiates `GameState.map.scene` (fallback `default_map`/`default_objective` for F6). End screen has Restart / Mission Select / Quit. Boss fights are solo: `WaveSpawner.despawn_all()` + `MeleeEnemy.despawn()` (no kill credit) when the boss appears. To add a mission: create the .tres and add it to MissionSelect's `maps`/`objectives` arrays. Phase 2 step 5: in-run rewards — `LootDropper` (added by RetroView; on `EventBus.enemy_killed` spawns an XP gem + rolls `EnemyData.drops` (`DropEntry` = material or `BoosterData` + chance + amount) with `GameState.rng`); `scenes/maps/pickup.tscn` (`Pickup`: magnet to nearest player, calls `Player.collect()`; shapes: diamond XP, cube material, plus heal, cone boost); `LevelComponent` (in-run XP/levels: +10 max HP, +2 attack per level) and `BoosterComponent` (heal / timed damage boost via `StatsComponent.damage_multiplier`; attacks use `stats.get_attack_power()`). Boosters in `resources/items/` (heal_potion, fury_tonic); new material goblin_ear. HUD shows level/XP bar/boost timer + Level Up banner. Phase 2 step 6 (Phase 2 done): results screen = `GameOverScreen.show_results(victory, time, kills, level, rewards)` with an 'Earned this run' tally (material swatch + name + amount; `GameState.get_material_data(id)` maps saved ids back to resources); HUD hides on results; on victory a deferred loot vacuum (`Pickup.attract()`, group `pickups`) pulls every remaining pickup to the player so nothing earned is lost. Phase 3 step 1: `SaveManager` profile = {version, currency, materials{id: count}, unlocks[], skill_points, stats{runs_played, runs_won}} in user://save.json (atomic temp-file write; corrupt file moved to save.corrupt.<time>.json; `_migrate()` merges defaults and converts JSON floats back to ints). RetroView calls `SaveManager.commit_run(GameState.run_rewards, victory)` when results show (after the loot vacuum); results rows show '(N owned)'. Material ids are Strings in the profile. Phase 3 step 2: the Camp — main scene is `scenes/main/hub.tscn` (`hub.gd`) loading `scenes/maps/camp.tscn` (campfire, tents, stations); stations use `components/interactable.gd` (`scenes/maps/interactable.tscn`: Area3D + '[E] Name' Label3D, `action` StringName, emits `interacted`), hub opens panels into `%PanelHost` (panels emit `closed`, player input disabled while open). Mission select is now the Mission Board panel (Back/Esc closes, Start → run). Results button is 'Return to Camp'. Rendering extracted into reusable `scenes/main/retro_screen.tscn` (`RetroScreen.add_world()`), used by camp and run (`retro_view.tscn` = the run scene). `MaterialRegistry` looks up MaterialData by id from resources/materials/. Player has `combat_enabled` (off in camp) and `is_interact_just_pressed()`. Phase 3 step 3: crafting — `ItemData` (`scripts/item_data.gd`: id, slot WEAPON/ARMOR/TRINKET, stat bonuses that can be negative, `cost: Array[MaterialCost]`) in `resources/items/` (goblin_charm, moonleaf_vest, tusk_cleaver, berserker_band; boosters share the folder and are skipped by `ItemRegistry`). `ResourceFolder.load_all()` shared by `MaterialRegistry`/`ItemRegistry`. Profile has `items: [id]`; `SaveManager.can_craft/craft/has_item` hold the rules (craft once, spend materials, save). Forge station opens `scenes/ui/forge_panel.tscn`. Phase 3 step 4: equipment loadout — profile `equipped: {weapon, armor, trinket: item id or \"\"}` (`SaveManager.equip/unequip/get_equipped/equipped_items/is_equipped`; migration clears equips of unowned items). `EquipmentComponent` on the player (after HealthComponent) adds gear bonuses on spawn via static `EquipmentComponent.totals()` (max HP floored at 1). Gear Rack station (camp, between the tents) opens `scenes/ui/loadout_panel.tscn`. `CameraFollow` now centers the target on start (`_centering_offset()`, `look_height`), so maps can place the player anywhere. Phase 3 step 5: 8-slot loadout — `ItemData.Slot` = MAIN_HAND, OFF_HAND, HELMET, CHEST, WAIST, BOOTS, TRINKET, CONSUMABLE; `ItemData.two_handed`, `tier`, `category`, `can_go_in(slot)`, `slot_key()`. `SaveManager` v2 (migrates v1 weapon→main_hand, armor→chest; `_clean_equipped` drops unowned/misfit equips); `equip(item, slot)` applies hand rules; `hands_full()`. Items regenerated (10 total incl. shiv, wand, buckler, hood, belt, sandals). Loadout panel is a paper-doll grid (`DOLL` layout const). Phase 3 step 6: learning-by-doing — `scripts/progression.gd` (`Progression`: track keys \"gathering|crafting|mastery/<category>\", curves TRACK 30+20(L-1) / RANK 100+50(L-1), max 100, XP amounts, `all_track_keys()`, `display_name()`). Profile `xp: {track: int}`, `rank_xp` (= every XP gained); `SaveManager.add_xp/get_track_xp/get_track_level/get_rank`; crafting gives 25×tier immediately; run XP collected in `GameState.run_rewards[\"xp\"]` (gathering from `EventBus.resource_harvested`, `MaterialData.gather_skill`; mastery = enemy xp_reward to every equipped weapon/armor category, `fists` if main hand empty) and committed in `commit_run()` (returns level-ups → results screen lines). Skill Shrine opens `scenes/ui/shrine_panel.tscn`. Phase 3 step 7: tiers & gating — `Progression.TIER_LEVELS`/`level_needed()`/`requirement_text()`; `SaveManager` v3: `items: {id: count}` (v2 list → count 1), repeat crafting, `meets_tier()`, `can_craft_tier()`, `can_use_tier()` (mastery; trinkets ungated), `equip()` uses one copy per slot, `_clean_equipped()` also drops gear above your mastery. `MaterialData.tier` + `GatherNode` refuses below the gather level ('Requires Herbalism 3'). `ObjectiveData/MapData.required_rank` (Ogre: Rank 2, new 'Gather Sunbloom': Rank 3) locked on the Mission Board. New: sunbloom (T2 herb), goblin_hatchet (T1 axe), sunbloom_robe (T2 chest). Forge recipe list scrolls. Phase 3 step 8: consumable slot — `ItemData.use_effect` (a `BoosterData`, reuses `BoosterComponent.apply`) + `use_cooldown`; `BoosterData.describe()` for UI text. `SaveManager.consume_equipped()` spends one copy immediately (saved, empties the slot at 0). `ConsumableComponent` on the player (`try_use()`, refuses heals at full HP, signals `used`/`changed`); input action `use_consumable` (Q / D-pad up). HUD adds a `SkillSlot` for it (SkillSlot.setup now takes title, action, cooldown; `show_empty()`). Potions: moonleaf_draught (T1, heal 40), goblin_grog (T2, +25% dmg 15 s), category `potion` (Potion Crafting track). Drop boosters (heal_potion/fury_tonic pickups) are unchanged. Phase 3 step 9: skill points replace auto-levelling tracks — `SaveManager` v4: profile `track_levels: {track: level}` (missing = 1) instead of per-track `xp`; `add_rank_xp()` grants `SKILL_POINTS_PER_RANK` per Rank gained; `level_track(track)` spends `TRACK_LEVEL_COST`; `commit_run` returns Rank-ups `{level, points}`. Run XP is still collected per track in `run_rewards["xp"]` (shown on results as where Rank XP came from). v3 migration keeps old track levels (via `V3_TRACK_CURVE`) and grants points = Rank-earned minus levels already held. Shrine panel: skill points line + '+ Level' button and 'Unlocks T2 at Lv 3' hint per track (`Progression.next_tier()`). Phase 3 step 10: challenge missions — `ChallengeData` (`scripts/challenge_data.gd`, .tres in `resources/challenges/`: normal, hard (Rank 2: HP x1.5, dmg taken x1.3, rewards x1.5), brutal (Rank 5: x2.2, x1.7, x2.5)) picked in the Mission Board's Difficulty column (`challenges` array, first = default) for any map + objective -> `GameState.challenge` (null = Normal). Enemy/boss HP via `GameState.enemy_health_multiplier()` at spawn (MeleeEnemy, OgreBoss); player damage via `HurtboxComponent.damage_taken_multiplier` (set in Player._ready). `GameState.apply_challenge_bonus(victory)` multiplies run materials + XP (ceil) on victory only, called in RetroView before `commit_run`; results line 'Hard cleared: rewards x1.5'; HUD prefixes the objective with '[Hard]'. New enemies must apply `GameState.enemy_health_multiplier()` too. Phase 4 step 1: characters — `CharacterData` (`scripts/character_data.gd`: id, name/role/description keys, sort_order, base max_health/attack_power/defense/move_speed/dodge_cooldown, placeholder color + body_scale) in `resources/characters/` (brawler, warden, mystic), `CharacterRegistry` (falls back to the first character for unknown ids). `CharacterComponent` on the player (right after StatsComponent; writes base stats; `data` empty = `SaveManager.get_character()`), `Player._apply_character()` sets speed/dodge/tint/scale. `SaveManager` v5: `character` id + `loadouts: {character_id: {slot: item}}` (v4 loadout copied to every character); all loadout calls use the chosen character's. Main scene is `scenes/main/character_select.tscn` (cards; press the selected card again or Confirm → camp); Hero Tent station (`action = &"heroes"`, in front of Tent1) opens it in camp. Gear Rack title shows whose loadout; totals use the character's base stats. Phase 4 step 1b: heroes live in the camp — main scene `scenes/main/title_screen.tscn` → hub. `scenes/maps/hero_area.gd` (`HeroArea`: `character`, `side` enum `ScreenSide` (NOT `Side`: Godot has a global enum with that name), `card_on_right()`); camp widened to ±15 with BrawlerArea/WardenArea/MysticArea (rotated so -Z faces the campfire) + `Overview` marker (camp center). `CampHeroes` (`scenes/main/camp_heroes.gd`, created by hub): spawns a Player per area (`controlled = false`, own `CharacterComponent.data`), adds an Interactable (`action = &"hero"`) to each, `control(character)` swaps control, walks the old hero home via `PlayerInput.scripted_direction`. Player: `controlled` export + `set_controlled()` (only controlled bodies are in group `players`), `face_toward()`; Interactable only reacts to controlled players. `EquipmentComponent.character` → wears that character's loadout (`SaveManager.equipped_items(id)`). Card UI `scenes/ui/hero_card.tscn` (`HeroCard`: confirmed/closed/browse). Hub: `GameState.character` null = choosing mode (camera follows a `_focus` node shifted `CHOOSE_SHIFT` away from the card, zoom 16), else play as that hero; mouse picking via `_gui_input` + ray on physics layer 2 (`RetroScreen.to_game_position()`). Removed: character_select scene, Hero Tent. Phase 4 step 2: passives — `PassiveData` (`scripts/passive_data.gd`: `kind` BLOODRUSH/BULWARK/ATTUNEMENT + grouped numbers, `describe()` builds card text from the numbers) in `resources/passives/`, `CharacterData.passive`. `PassiveComponent` on the player (after SkillCaster; exports character/stats/hurtbox/skill_caster). `StatsComponent` damage boosts are now named + multiplied: `set_damage_modifier(source, mult)` / `get_damage_multiplier()` (boosters use &"booster", Bloodrush &"bloodrush") — never assign a single multiplier. `SkillCasterComponent.cooldown_speed`. Player: hurtbox multiplier is `*=` challenge (on top of Bulwark), knockback × `passives.knockback_taken()`. HUD boost label also shows `passives.status_text()`; hero card shows the passive. Bloodrush counts every kill for now (Phase 5: needs killer attribution). New passive = new Kind + match branch in PassiveComponent + a .tres. Phase 4 step 3A: skills — `CharacterData.signature_skills` (keys 1–2) + `basic_attack` (SkillData; set = attack button casts it, e.g. Magic Bolt), `ItemData.skills` (main-hand weapon skills, keys 3–4; empty = `CharacterComponent.unarmed_skills`, currently Ground Slam as placeholder). `CharacterComponent.skill_loadout()` builds the list from that character's own main hand; Player._ready calls `skill_caster.set_skills()`. `SkillCasterComponent`: `set_skills`, `try_cast(slot, caster, dir, world)`, `try_basic()` (own cooldown = SkillData.cooldown; not sped up by Attunement), `basic_ready()`. `SkillEffect.caster` = the Player (effects call `Player.dash(dir, speed, time, invulnerable)` — the dodge roll is now a dash too — and `Player.blink(target, invuln_time)`, or change `caster.hurtbox`). `Projectile` (`scenes/player/skills/projectile.gd`): flies straight, a `Sensor` Area3D (mask world+enemy bodies) stops it on contact and it lingers 2 physics frames so the hurtbox registers the hit; `magic_bolt.tscn`. Effects in `scenes/player/skills/`: dash_strike, whirlwind (pulsing hitbox), shield_bash, iron_guard (hurtbox multiplier ×0.4 for 3 s), arcane_barrage (spawns bolts deferred), blink (raycast at 0.4 m on layer 1 so fences block). Hero card lists skills + ranged attack. Phase 4 step 3B: weapon skills — generic effect scripts: `frontal_strike.gd` (hits/hit_interval/active_time/lunge; scenes shield_bash, cleave, haymaker, flurry — `hit_interval` must stay above enemies' hurtbox `hit_cooldown` 0.2 or hits are eaten) and `projectile_fan.gd` (`projectile_scene`, count, spread; scenes arcane_barrage, fan_of_knives). Projectile scenes: magic_bolt, hatchet_throw, knife, moonleaf_bolt. `healing_bloom.gd` heals a fraction of max HP over ticks (exact total). `ItemData.skills_text()` shown in Forge + Gear Rack. Note: .tscn property lines can't carry comments. Phase 4 step 4: talent trees — `TalentData` (`scripts/talent_data.gd`: id, tier 1–3, `exclusive_group` (same group = choose one), percent fields max_health/damage/move_speed/damage_taken, `passive_bonus`, optional `skill` + skill_damage/cooldown percent; `cost()` = tier (1/2/3); `effect_lines()`; static `totals()`), .tres in `resources/talents/<hero>/`, `CharacterData.talents`. `SaveManager` v6: `talents: {character_id: [ids]}`, `talent_block()` (&""/owned/other_chosen/needs_tier/no_points) + `buy_talent()`; `owned_talents()`. `TalentComponent` on the player (after EquipmentComponent: scales final max HP, adds &"talents" damage modifier, hurtbox multiplier, sets SkillCaster `skill_damage_mods`/`skill_cooldown_mods`; `move_speed_multiplier()`, `passive_bonus()` read by Player/PassiveComponent). `SkillCasterComponent.cooldown_of(skill)` (HUD uses it). Shrine panel has Tracks / '<Hero> Talents' tabs; `scenes/ui/talent_tree_view.gd` (`TalentTreeView`). Gear Rack totals don't include talents yet. Testing tip: the user often has the game running — tests must not write the save (set profile fields in memory only), and a changed save.json with an older `version` came from their running game. Balance step: mana + stamina — `MeterComponent` (`components/meter_component.gd`: max, regen/s, per_kill refill, `spend/has/restore`, `changed` signal); player has `StaminaMeter` + `ManaMeter`, configured from `CharacterData` (max_stamina, stamina_regen, max_mana, mana_regen, mana_per_kill; Brawler 110 ST/30 MP, Warden 120/30, Mystic 60/100 + 8 mana per kill). `SkillData.kind` PHYSICAL (stamina) / MAGIC (mana), `cost`, `cast_time`. Basic attacks and dodge are free. `SkillCasterComponent`: `can_afford`, `meter_for`, casting state (`is_casting`, `cast_progress`, `update_cast_direction`, `cancel_cast` refunds; cost paid at cast start, cooldown starts when it fires; signals cast_started/cast_ended). Player: `cast_move_factor` 0.4 while casting, dodge cancels the cast, aim tracked during the cast. Cast times: Arcane Barrage 0.5, Moonleaf Bolt 0.6, Healing Bloom 0.8. Cooldowns raised on big hitters (Ground Slam 8, Cleave 7, Whirlwind 8, Dash Strike 6, Hatchet Throw 5, Moonleaf Bolt 5). `BoosterData.Effect.RESTORE_MANA`; new consumable `mana_draught` (T1 potion: 2 Moonleaf + 2 Sunbloom, +50 mana). HUD: Stamina/Mana bars with text, skill cost on each slot ('25 MP'/'30 ST'), 'No mana'/'No stamina' when unaffordable, cast bar. Hits don't interrupt casts (accessibility); revisit if casting feels too safe. Phase 4 step 5: elements — `Element.Type` (`scripts/element.gd`: PHYSICAL, FIRE, ICE, POISON; `name_key()`), `SkillData.element` + `display_name()` ('Whirlwind (^ Fire)', used by hero card and weapon text; HUD shows it next to the key), `SkillEffect.element` -> `HitboxComponent.element` (every effect copies it next to `hitbox.damage`; new effects must too). `EnemyData` fire/ice/poison_multiplier + `can_be_frozen` + `element_multiplier()`. `StatusEffectComponent` (`components/status_effect_component.gd`, a Node3D child of each enemy, exports health + label_height; owner sets `status.data`, HurtboxComponent `status` export calls `element_multiplier()` before damage and `on_hit()` after; no status on players yet). Burn = 40% of the hit over 3 s (refreshes, strongest wins). Poison = 8% of the hit per second per stack, max 5, 4 s, all stacks end together. Chill = -20% speed per stack, 3 s, resistance weakens the slow; 3rd stack = Freeze 1.5 s, then 3 s immunity so fast attacks can't freeze-lock (decided during implementation, not in the original design). DoTs skip defense and hit stop. Status text uses ASCII symbols (^ Burn, * Chill, # Frozen, ~ Poison) so no glyphs are missing and color is never the only cue. New enemies need a StatusEffectComponent node, `hurtbox.status` set, `status.data = data` and to read `status.speed_multiplier()` / `is_frozen()`; `despawn()` must call `status.clear()` so a DoT can't earn a kill later. Phase 4 step 6: biome variants — `BiomeData` (`scripts/biome_data.gd`, `resources/biomes/`: snow, desert), `MapData.biome` (empty = base enemies), `GameState.biome()`. A variant is a full `EnemyData` .tres with `biome` set, listed in the base type's `variants`; enemies call `data = data.variant_for(GameState.biome())` then `data.apply_look(visual)` at the top of `_ready` (new enemy types must too; status, loot, XP and the boss bar then read the variant). `EnemyData.tint` + `accessory` scene + `accessory_scale` (shape difference, never color alone; `scenes/enemies/variants/`: frost_spikes, mummy_wraps, sized for a goblin, ogre uses scale 3). Frost Goblin: Fire x2, Ice x0.5, can't freeze, drops Frost Shard 40%. Mummified Goblin: Fire x0.5, Ice x1.5, Poison x0.25, drops Burial Wrap 40%. Ogre variants have matching multipliers. Trinkets frost_heart + burial_talisman (T2) use the exclusive materials. Maps frost_pass (Rank 4) and sunscar_dunes (Rank 6) reuse greybox.tscn as a PLACEHOLDER until the 3-maps step; Gather missions still give the same herbs on every map. Testing tip: `physics_frame` fires BEFORE nodes process, and timers using ignore_time_scale + process_in_physics run erratically under hit stop — use wall-clock waits in tests.
- **Next thing to do:** Gameplay adjustments below, one at a time (test each before the next). Then resume Phase 4: 3 maps with distinct mood, lighting and weather (Frost Pass and Sunscar Dunes still reuse greybox.tscn; Training Grounds needs a forest look).
- **Gameplay adjustments (team request):**
  - [x] 1. Hero skills consume mana. *Signature skills (keys 1-2) are `kind = MAGIC`; weapon skills (keys 3-4) still depend on the weapon. Pools raised so they can be paid: Brawler 70 MP, 3/s, +5 per kill; Warden 60 MP, 3/s, +4 per kill; Mystic unchanged.*
  - [x] 2. All attacks follow a Dark Souls-style attack: wind up, commit to the attack, and dashing can cancel the wind-up. *`SkillData.cast_time` = wind-up, `commit_time` = lock after firing; melee has `MeleeAttackComponent.windup_time/commit_time` + `start_attack()` (enemies keep their own wind-up and call `attack()`). Player: `is_winding_up()`, `is_committed()`, walk x0.4 in wind-up, x0.15 in commit, lean back/forward telegraph, dodge cancels wind-up + refunds, dodge is refused in commit (0.2 s input buffer). New skills need both times set. Basic attack rates unchanged: melee 0.15 + 0.2, Magic Bolt 0.2 + 0.3 cooldown. Hits don't interrupt either phase (accessibility).*
  - [ ] 3. Basic attacks and dash consume stamina (they are free today).
- **Known bugs:** goblins walk straight at the player and can snag on crates (no pathfinding yet).
- **Playtest notes:** Phase 1 felt too easy — likely due to the simple attacks/defense; revisit difficulty when Phase 4 adds more skills, characters and enemy variety.
- **Design decisions:** boss fights are solo (no adds) — the team prefers the pure duel feel; difficulty should come from added mechanics, not extra pressure.
- **Audio:** the team makes all sounds — don't add audio files. Hook points for SFX: `HurtboxComponent.hurt`, `MeleeAttackComponent.attacked`, `SkillCasterComponent.skill_used`, `Player.dodged`, `ConsumableComponent.used`, `HealthComponent.died`, `EventBus.wave_started` / `enemy_killed` / `player_died`.
