# Torque & Tombs

Top-down vehicular action roguelite for **Godot 4.7** (GDScript). Drive an armed buggy through
procedurally connected tomb rooms, survive arena lockdowns, jump lava, smash crates for scrap,
then spend it in the Garage on weapons, engines, armor and tires.

## Open & play

1. Open Godot 4.7, click **Import**, and pick `project.godot` in this folder.
2. Press **F5** (Play). The game starts at the main menu.
3. Pick **Tutorial** first. It teaches every mechanic in about two minutes and ends in the Garage.

| Action        | Keyboard / Mouse | Gamepad       |
|---------------|------------------|---------------|
| Drive / brake | W / S (or arrows)| RT / LT       |
| Steer         | A / D            | Left stick    |
| Drift         | Space (hold while turning, release for a boost) | A |
| Nitro         | Shift            | X             |
| Fire rocket   | E / Right mouse  | RB            |
| Roof turret   | automatic        | automatic     |
| Shop          | Park in the bay, F in the bay, or Tab anywhere in the Garage | Y / Back |
| Pause         | Esc / P          | Start         |

## Game loop

- **Garage** (`scenes/garage/GarageHub.tscn`): drive into the yellow SHOP bay to open the shop. Drive into the
  START RUN teleporter to begin a run.
- **Dungeon** (`scenes/world/Dungeon.tscn`): a new random layout every run. You'll meet:
  - Start rooms
  - two kinds of maze rooms, with spike traps and roaming rammers
  - lava platform rooms, with boost-pad jumps
  - arenas, where the doors lock and three waves attack
  - treasure vaults
  - the boss room, where a Juggernaut guards the exit teleporter
- **Rooms** are 56 m square. In the lava platform room, the jump lanes sit beside the doorways rather than in front
  of them.
- **Depth:** every successful run takes you one level deeper. Enemies gain +20% health, +15% damage, a little speed
  and a faster fire rate per level, and the waves themselves grow (see below). Enemy scrap grows +10% per level so
  upgrades stay reachable.
- **Random waves:** arenas roll 2–4 waves each time you enter. The count rises with depth. Each wave buys random
  enemies with a "threat budget" (rammer 2, fire caster 3, mortar buggy 5) that grows with the wave number and the
  depth. From depth 4, elite Juggernauts can join normal arenas; from depth 6, Pyre Archons and Siege Crawlers can
  too. Boss rooms roll random warm-up waves, and their final wave is always the boss with random escorts.
- **Score screen:** back in the garage after each run you get time, scrap, kills, rooms cleared, best combo, boss
  defeated and damage taken, plus a score and your best score. Faster and deeper runs score more.
- **Economy:** a normal run earns roughly 150–200 scrap, enough for one or two upgrades (tier 1 costs 50–180, and each
  tier costs 1.5× the last). Treasure vaults are rare side rooms (about one run in three) with gold crates and loose
  scrap worth about 130, i.e. an extra upgrade or two.
- **Gauntlet rooms** sit on straight stretches of the path. A 15 m lava or spike trench splits the room, and the only
  way across is the boost pad and ramp in front of the entry door. They're one-way, like the rest of the run.
- **Bosses:** each run's exit is guarded by one of three bosses at random, never the same one twice in a row:
  - the Juggernaut, a giant rammer
  - the Pyre Archon, a giant fire caster that fires 5-fireball fans
  - the Siege Crawler, a giant mortar buggy that drops 5-shell barrages around you
- **Combos:** drifts, air time (with a bonus for clean landings) and quick kills each add style points and +1 to the
  multiplier, up to x8. If you go 3.5 s without a new trick, the combo cashes in as scrap. Getting wrecked loses it.
  Combos only count during runs and the tutorial.
- **Crates** smash on contact without slowing you down.
- **Utility tab:** Scrap Magnet (2 tiers, pull range 7 → 19 → 31 m) and Scrap Vacuum (auto-collects every piece of
  scrap in the room you're in).
- **Targeting Computer** (shop, Weapons tab): the rocket pod swivels to fire wherever the mouse points, or the right
  stick on a gamepad.
- Reach the exit teleporter to bank your scrap and get a bonus. If you're wrecked you lose half of the scrap you found
  that run.
- Progress saves to `user://torque_tombs_save.json`. Use **Reset Save** in the main menu to start over.

## Folder layout

```
scripts/      All gameplay code (see docs/SETUP.md for what each script does)
scenes/       Generated scenes: player, enemies, projectiles, hazards, rooms, levels, UI
models/       Low-poly meshes (.tres), flat-shaded with vertex colors
materials/    Shared materials (vertex-color, metal, glow, lava, particles)
audio/        Placeholder synthesized sound effects (swap in real ones anytime)
data/         WeaponResource and UpgradeResource files (shop items live in data/upgrades/)
ui/           UI theme
tools/        The generator that built all of the above, plus playtest scripts
docs/         SETUP.md: script reference, node hierarchies, physics layers
```

## Editing

Everything is ordinary Godot content, so you can open any scene and change it in the editor:
- **Tune the buggy:** open `scenes/player/PlayerVehicle.tscn` and select the root. All the handling,
  drift, boost and air settings are in the Inspector. Base stats are in `scripts/autoload/PlayerData.gd`.
- **Add a shop item:** right-click `data/upgrades/`, choose New Resource, pick UpgradeResource, and fill it in. It appears in
  the shop automatically.
- **Change waves:** open a room in `scenes/world/rooms/`, select `WaveSpawner`, and edit `waves`.
- **New room:** duplicate a room scene. Keep the `Sockets/North|East|South|West` markers and their
  `Blocker` children at the edges of a 40 x 40 m footprint. Then add the scene to the `DungeonGenerator`
  in `Dungeon.tscn`.

## Regenerating (optional)

`tools/build.gd` recreates every model, scene and data file from code:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/build.gd
```

**This overwrites** `scenes/`, `models/`, `materials/`, `audio/`, `data/` and `ui/`. Only use it if you'd
rather change the generator than the scenes. The headless playtest (77 checks) covers:
- a full dungeon run, the shop, death and the tutorial
- lava jumps and the gauntlets, wall-hopping and crate smashing
- combos, aimed rockets, the bosses and enemy pathfinding
- depth scaling, the score screen, the scrap magnet and vacuum, and treasure frequency

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/tests/run_tests.gd
```
