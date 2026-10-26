# Torque & Tombs: Godot 4 script setup

These are GDScript files only. Make the scenes yourself in the editor, using the node
trees below. Most scripts find their child nodes by name (shown in the trees), so if you keep
those names you only need to fill in a few Inspector slots. You can also drag any node into the
matching `@export` slot to override the name lookup.

---

## 1. Copy the scripts

Drop the whole folder into your project, e.g. `res://scripts/`:

```
scripts/
  autoload/     PlayerData.gd, GameManager.gd
  resources/    WeaponResource.gd, UpgradeResource.gd, WaveData.gd, SpawnGroup.gd
  player/       PlayerVehicle.gd, WeaponMount.gd, TurretController.gd, RocketLauncher.gd, IsometricCamera.gd
  projectiles/  Bullet.gd, Rocket.gd
  enemies/      BaseEnemy.gd, RammerEnemy.gd, RangedEnemy.gd, TrainingDummy.gd, WaveSpawner.gd
  world/        BaseRoom.gd, ArenaRoom.gd, ExitRoom.gd, DungeonGenerator.gd, Door.gd, Teleporter.gd, TutorialLevel.gd
  hazards/      LootCrate.gd, ScrapPickup.gd, SpikeTrap.gd, BoostPad.gd, LavaPit.gd
  effects/      OneShotEffect.gd
  ui/           MainMenu.gd, PauseMenu.gd, OptionsMenu.gd, HUD.gd, ShopUI.gd
  garage/       GarageHub.gd
```

## 2. Autoloads (order matters)

Project Settings > Globals > Autoload:

| Order | Name          | Path                              |
|-------|---------------|-----------------------------------|
| 1     | `PlayerData`  | `res://scripts/autoload/PlayerData.gd`  |
| 2     | `GameManager` | `res://scripts/autoload/GameManager.gd` |

## 3. Scene paths

`GameManager.gd` changes scenes using these paths. Save your scenes there, or edit the constants
at the top of `GameManager.gd`:

```
res://scenes/ui/MainMenu.tscn
res://scenes/garage/GarageHub.tscn
res://scenes/world/Dungeon.tscn
res://scenes/world/TutorialLevel.tscn
```

Set `MainMenu.tscn` as the main scene (Project Settings > Application > Run).

## 4. Input actions

`GameManager` registers these at startup **if they don't already exist**, so you don't have to set
anything up. If you add them yourself in Project Settings > Input Map, your bindings win.

| Action        | Keyboard / Mouse | Gamepad       |
|---------------|------------------|---------------|
| `accelerate`  | W, Up            | Right trigger |
| `brake`       | S, Down          | Left trigger  |
| `steer_left`  | A, Left          | Left stick    |
| `steer_right` | D, Right         | Left stick    |
| `drift`       | Space            | A             |
| `boost`       | Shift            | X             |
| `fire_rocket` | E, Right mouse   | RB            |
| `interact`    | F                | Y             |
| `toggle_shop` | Tab              | Back/Select   |
| `pause`       | Esc, P           | Start         |

## 5. Physics layers

Name them in Project Settings > Layer Names > 3D Physics:

| # | Name               | Used by |
|---|--------------------|---------|
| 1 | World              | Floors, walls, ramps, door gates, socket blockers |
| 2 | Player             | PlayerVehicle |
| 3 | Enemies            | Enemies, training dummies |
| 4 | PlayerProjectiles  | Player bullets/rockets |
| 5 | EnemyProjectiles   | Enemy fireballs/shells |
| 6 | Triggers           | Room entrance triggers, lava, boost pads, spike areas, teleporters |
| 7 | Breakables         | Loot crates |

| Node | Layer | Mask |
|------|-------|------|
| PlayerVehicle | 2 | 1, 3, 7 |
| Enemy (CharacterBody3D) | 3 | 1, 2, 3, 7 |
| TrainingDummy | 3 | none |
| LootCrate | 7 | 1, 2, 3, 7 |
| Player Bullet / Rocket (Area3D) | 4 | 1, 3, 7 |
| Rocket's SplashArea | none | 3, 7 |
| Enemy projectile (Area3D) | 5 | 1, 2 (RangedEnemy sets the mask to 1+2 automatically) |
| Enemy shell's SplashArea | none | 2 |
| Turret DetectionArea | none | 3 |
| EntranceTrigger, ShopZone, Teleporter, BoostPad | 6 | 2 |
| LavaPit, Spike HurtArea | 6 | 2, 3 |

## 6. Groups (added automatically by the scripts)

`player`, `enemies`, `breakable`, `unsafe_ground` (LavaPit).
Also add **your own** lava floor StaticBody3D to `unsafe_ground` so it's never saved as a respawn point.

Every damageable thing has `take_damage(amount: float, source: Node = null)`.

---

## 7. Scene node trees

Rules that apply to every scene:
- **-Z is forward.** Model the buggy, enemies, doors, sockets and boost pads facing -Z.
- `(Type) [Script.gd]` means a node of that type with that script attached.
- Names in **bold** are the names the scripts look up automatically.

### PlayerVehicle.tscn

```
PlayerVehicle (CharacterBody3D) [PlayerVehicle.gd]         layer 2, mask 1,3,7
├── CollisionShape3D (BoxShape3D ≈ 2 × 1 × 3.4, lifted so the bottom sits at y = 0)
├── **VisualRoot** (Node3D)            ← tilts for ramps / air pitch & roll. Keep scale 1.
│   ├── Body (MeshInstance3D)
│   ├── Wheel_FL / FR / RL / RR (MeshInstance3D)
│   ├── DriftParticlesLeft  (GPUParticles3D, Local Coords OFF)   → drag into drift_particles
│   ├── DriftParticlesRight (GPUParticles3D, Local Coords OFF)   → drag into drift_particles
│   ├── BoostParticles (GPUParticles3D)                          → boost_particles
│   ├── **Mounts** (Node3D)            ← shop visuals get attached under these
│   │   ├── RoofMount (Node3D)
│   │   ├── FrontMount (Node3D)
│   │   └── SideMounts (Node3D)
│   ├── RoofTurret (Node3D) [TurretController.gd]     slot_name = "turret", weapon = autocannon.tres
│   │   ├── TurretMesh (MeshInstance3D)
│   │   ├── **Muzzle** (Marker3D)      ← at the barrel tip, -Z pointing out of the barrel
│   │   ├── MuzzleFlash (GPUParticles3D, One Shot)    → muzzle_flash
│   │   ├── FireSound (AudioStreamPlayer3D)           → audio_player
│   │   └── **DetectionArea** (Area3D)  mask 3, Monitorable OFF
│   │       └── CollisionShape3D (SphereShape3D, radius set from weapon.detection_range)
│   └── RocketLauncher (Node3D) [RocketLauncher.gd]   slot_name = "rocket", weapon = rocket.tres
│       ├── LauncherMesh (MeshInstance3D)
│       └── **Muzzle** (Marker3D)
└── EngineAudio (AudioStreamPlayer3D, looping engine sound)  → engine_audio
```

### Bullet.tscn / Rocket.tscn / EnemyFireball.tscn / MortarShell.tscn

```
Bullet (Area3D) [Bullet.gd]                 layer 4, mask 1,3,7
├── CollisionShape3D (SphereShape3D r = 0.15)
└── Mesh (MeshInstance3D, small emissive capsule along Z)

Rocket (Area3D) [Rocket.gd]                 layer 4, mask 1,3,7
├── CollisionShape3D (SphereShape3D r = 0.25)
├── Mesh (MeshInstance3D)
├── Trail (GPUParticles3D)
└── **SplashArea** (Area3D) mask 3,7, Monitorable OFF
    └── CollisionShape3D (SphereShape3D, radius set at runtime)

EnemyFireball (Area3D) [Bullet.gd]          layer 5, mask 1,2    hit_groups = ["player"]
MortarShell  (Area3D) [Rocket.gd]           layer 5, mask 1,2    hit_groups = ["player"], SplashArea mask 2
```
Set `impact_effect` to an explosion scene that uses **OneShotEffect.gd**.

### Enemies: RammerEnemy.tscn / RangedEnemy.tscn

```
RammerEnemy (CharacterBody3D) [RammerEnemy.gd]          layer 3, mask 1,2,3,7
├── CollisionShape3D
├── **Visual** (Node3D)                 ← rotated to face movement; meshes here get the hit flash
│   └── Mesh (MeshInstance3D)
└── **NavigationAgent3D** (NavigationAgent3D, Path Desired Distance ≈ 1, Target Desired Distance ≈ 1.5)

RangedEnemy (CharacterBody3D) [RangedEnemy.gd]          layer 3, mask 1,2,3,7
├── CollisionShape3D
├── **Visual** (Node3D)
│   ├── Mesh (MeshInstance3D)
│   └── **Muzzle** (Marker3D)
├── **Telegraph** (Node3D at chest height)   ← aimed at the player and stretched along Z
│   └── Line (MeshInstance3D, BoxMesh 0.15 × 0.05 × 1, position z = -0.5, red unshaded material)
└── **NavigationAgent3D**
```
For a **Mortar Buggy**: same tree, set `use_mortar_arc = true`, `projectile_scene = MortarShell.tscn`,
and `landing_marker_scene` to a flat decal / dark disc mesh.
Assign `scrap_pickup_scene` on every enemy so it drops scrap.

### TrainingDummy.tscn (tutorial)

```
TrainingDummy (StaticBody3D) [TrainingDummy.gd]   layer 3
├── CollisionShape3D
└── Mesh (MeshInstance3D)
```

### Room scenes: StartRoom / MazeRoom / PlatformRoom / ArenaRoom / ExitRoom

All rooms share this layout. They're designed to fit one generator cell (default 40 × 40 m,
centred on the room origin). The generator removes the **Blocker** wall plug on connected sides
and places a Door there.

```
ArenaRoom (Node3D) [ArenaRoom.gd]          ← StartRoom/MazeRoom/PlatformRoom use BaseRoom.gd, ExitRoom uses ExitRoom.gd
├── **NavigationRegion3D** (NavigationRegion3D, bake in the editor, or tick bake_navigation_at_runtime)
│   ├── Floor (StaticBody3D + CollisionShape3D + Mesh)   layer 1
│   └── Walls (StaticBody3D ...)                          layer 1   ← leave a doorway gap on all 4 sides
├── **Sockets** (Node3D)
│   ├── **North** (Marker3D) pos (0, 0, -20)  rot Y   0°
│   │   └── Blocker (StaticBody3D + CollisionShape3D + Mesh)  ← wall plug filling the doorway
│   ├── **East**  (Marker3D) pos ( 20, 0, 0)  rot Y -90°
│   │   └── Blocker ...
│   ├── **South** (Marker3D) pos (0, 0,  20)  rot Y 180°
│   │   └── Blocker ...
│   └── **West**  (Marker3D) pos (-20, 0, 0)  rot Y  90°
│       └── Blocker ...
├── **EntranceTrigger** (Area3D) layer 6, mask 2
│   └── CollisionShape3D (BoxShape3D ≈ 32 × 4 × 32 — inset from the walls so doors close behind you)
├── **PlayerSpawn** (Marker3D)              ← StartRoom only
├── **WaveSpawner** (Node3D) [WaveSpawner.gd]   ← Arena / Exit only. Fill `waves` with WaveData.
│   ├── SpawnPoint1 (Marker3D)
│   ├── SpawnPoint2 (Marker3D)
│   └── SpawnPoint3 (Marker3D) ...
├── **RewardPoints** (Node3D)               ← Arena only (optional)
│   └── Marker3D ...
├── Hazards (Node3D)                        ← SpikeTrap, BoostPad, LavaPit, LootCrate instances
└── **Teleporter** (Teleporter.tscn)        ← ExitRoom only, destination = GARAGE
```
Each socket marker's **-Z must point out of the room**, which is what the rotations above give you.

### Dungeon.tscn

```
Dungeon (Node3D)
├── WorldEnvironment
├── DirectionalLight3D
├── DungeonGenerator (Node3D) [DungeonGenerator.gd]   ← assign room scenes, door_scene, player_scene
├── IsometricCamera (Camera3D) [IsometricCamera.gd]    ← finds the player automatically
├── HUD (HUD.tscn)
└── PauseMenu (PauseMenu.tscn)
```
(The generator spawns the player from `player_scene`. You can also put a PlayerVehicle instance
directly in the scene and the generator will move it to the start room.)

### Door.tscn

```
Door (Node3D) [Door.gd]                    ← spans the doorway along X, -Z points out of the room
├── Frame (MeshInstance3D)
├── **Gate** (AnimatableBody3D)  layer 1   ← modelled CLOSED, slides by open_offset (into the floor) when open
│   ├── CollisionShape3D
│   └── Mesh (MeshInstance3D)
├── LockedLight (OmniLight3D, red)          → locked_indicator
└── Audio (AudioStreamPlayer3D)             → audio_player
```

### Teleporter.tscn

```
Teleporter (Area3D) [Teleporter.gd]   layer 6, mask 2
├── CollisionShape3D (CylinderShape3D)
├── Pad (MeshInstance3D)
├── **ActiveVisual** (Node3D: glow mesh + GPUParticles3D)
└── **InactiveVisual** (Node3D: dim mesh)
```

### Hazards

```
LootCrate (RigidBody3D) [LootCrate.gd]       layer 7, mask 1,2,3,7, mass ≈ 20
├── CollisionShape3D (BoxShape3D)
└── Mesh (MeshInstance3D)

ScrapPickup (Node3D) [ScrapPickup.gd]        ← no physics needed
└── **Visual** (Node3D)
    └── Mesh (MeshInstance3D, small emissive gear)

SpikeTrap (Node3D) [SpikeTrap.gd]
├── Base (MeshInstance3D)
├── **Spikes** (Node3D, modelled EXTENDED)
│   └── Mesh (MeshInstance3D)
├── **HurtArea** (Area3D) layer 6, mask 2,3
│   └── CollisionShape3D
├── **TriggerArea** (Area3D) layer 6, mask 2   ← only for TRIGGERED mode
│   └── CollisionShape3D
└── Audio (AudioStreamPlayer3D)                 → audio_player

BoostPad (Area3D) [BoostPad.gd]              layer 6, mask 2   (-Z = launch direction)
├── CollisionShape3D (flat BoxShape3D)
├── Mesh (MeshInstance3D, chevron texture)
├── Effect (GPUParticles3D, One Shot)           → effect
└── Audio (AudioStreamPlayer3D)                 → audio_player

LavaPit (Area3D) [LavaPit.gd]                layer 6, mask 2,3
├── CollisionShape3D (wide flat box just above the lava surface)
└── LavaMesh (MeshInstance3D, emissive)
```
Lava jump layout: `BoostPad → Ramp (StaticBody3D, layer 1) → LavaPit → landing platform`.

### Effects (explosions, sparks, scrap bursts)

```
Explosion (Node3D) [OneShotEffect.gd]       lifetime ≈ 2
├── Fire (GPUParticles3D, One Shot, Explosiveness 1)
├── Smoke (GPUParticles3D, One Shot)
└── Flash (OmniLight3D)                     (optional)
```

### HUD.tscn

```
HUD (CanvasLayer) [HUD.gd]
└── Root (Control, Full Rect, Mouse Filter = Ignore)
    ├── TopLeft (VBoxContainer)
    │   ├── HealthBar (ProgressBar)        → health_bar
    │   ├── HealthLabel (Label)            → health_label
    │   └── BoostBar (ProgressBar)         → boost_bar
    ├── ScrapLabel (Label, top right)      → scrap_label
    ├── SpeedLabel (Label, bottom right)   → speed_label
    └── MessageLabel (Label, centred, autowrap, big font)  → message_label
```

### ShopUI.tscn (used inside GarageHub)

```
ShopUI (Control, Full Rect) [ShopUI.gd]
├── Dim (ColorRect, Full Rect, black 60 %)
└── Panel (PanelContainer, centred, ≈ 900 × 600)
    └── VBox (VBoxContainer)
        ├── Header (HBoxContainer)
        │   ├── Title (Label "GARAGE SHOP", expand)
        │   └── ScrapLabel (Label)          → scrap_label
        ├── Tabs (TabContainer, expand vertically)   → tab_container   (filled by code)
        ├── FeedbackLabel (Label)           → feedback_label
        └── CloseButton (Button "Close")    → close_button
```
Shop items are `UpgradeResource` `.tres` files in `res://data/upgrades/` (or dragged into the
`upgrades` array).

### GarageHub.tscn

```
GarageHub (Node3D) [GarageHub.gd]
├── WorldEnvironment / lights
├── Floor & walls (StaticBody3D, layer 1)
├── PlayerSpawn (Marker3D)                  → player_spawn
├── ShopZone (Area3D) layer 6, mask 2       → shop_zone   (marked parking bay)
│   └── CollisionShape3D
├── StartRunTeleporter (Teleporter.tscn, destination = NEW_RUN)
├── IsometricCamera (Camera3D) [IsometricCamera.gd]
├── HUD (HUD.tscn)
├── UI (CanvasLayer)
│   ├── ShopPrompt (Label "Park here or press F to open the shop")  → prompt_label
│   └── ShopUI (ShopUI.tscn)                → shop_ui
└── PauseMenu (PauseMenu.tscn)
```
Set `player_scene = PlayerVehicle.tscn`, or place a PlayerVehicle instance in the scene.

### MainMenu.tscn

```
MainMenu (Control, Full Rect) [MainMenu.gd]
├── Background (TextureRect / ColorRect)
├── MainPanel (VBoxContainer, centred)      → main_panel
│   ├── Title (Label "TORQUE & TOMBS")
│   ├── PlayButton (Button)                 → play_button
│   ├── TutorialButton (Button)             → tutorial_button
│   ├── OptionsButton (Button)              → options_button
│   ├── ResetButton (Button)                → reset_button
│   ├── QuitButton (Button)                 → quit_button
│   └── ScrapLabel (Label)                  → scrap_label
└── OptionsMenu (OptionsMenu.tscn)          → options_menu
```

### OptionsMenu.tscn

```
OptionsMenu (Control, Full Rect) [OptionsMenu.gd]
└── Panel (PanelContainer, centred)
    └── VBox (VBoxContainer)
        ├── Label "Master"   + MasterSlider (HSlider)  → master_slider
        ├── Label "Music"    + MusicSlider  (HSlider)  → music_slider
        ├── Label "SFX"      + SfxSlider    (HSlider)  → sfx_slider
        ├── FullscreenToggle (CheckButton)             → fullscreen_toggle
        ├── VSyncToggle (CheckButton)                  → vsync_toggle
        └── BackButton (Button "Back")                 → back_button
```
Create **Music** and **SFX** buses in the Audio tab so those sliders do something.

### PauseMenu.tscn

```
PauseMenu (CanvasLayer) [PauseMenu.gd]
├── Panel (PanelContainer, centred)         → panel
│   └── VBox
│       ├── ResumeButton                    → resume_button
│       ├── OptionsButton                   → options_button
│       ├── AbandonButton                   → abandon_button
│       └── MainMenuButton                  → main_menu_button
└── OptionsMenu (OptionsMenu.tscn)          → options_menu
```

### TutorialLevel.tscn

```
TutorialLevel (Node3D) [TutorialLevel.gd]
├── Environment, lights, IsometricCamera, HUD, PauseMenu
├── PlayerSpawn (Marker3D)                                → player_spawn
├── ZoneA_Drift      (S-curve track)  + TriggerA (Area3D, mask 2) → zone_a_trigger
├── DriftGate (Door.tscn, start_locked = true)            → drift_gate
├── ZoneB_LavaJump   (BoostPad → Ramp → LavaPit → platform) + TriggerB → zone_b_trigger
├── ZoneC_Crates     + TriggerC → zone_c_trigger
│   └── Crates (Node3D)                                   → crates_root
│       └── LootCrate × N
├── CrateGate (Door.tscn, start_locked = true)            → crate_gate
├── ZoneD_Targets    + TriggerD → zone_d_trigger
│   └── Dummies (Node3D)                                  → dummies_root
│       └── TrainingDummy × N
├── TargetGate (Door.tscn, start_locked = true)           → target_gate
└── ZoneE  + TriggerE → zone_e_trigger
    └── Teleporter (Teleporter.tscn)                      → teleporter
```
Bake one NavigationRegion3D for the tutorial if you add real enemies there.

---

## 8. Resources to create

Right-click in the FileSystem > **New Resource...** and pick the class.

**Weapons** (`res://data/weapons/`)

| File | projectile_scene | damage | fire_rate | speed | splash_radius | detection_range |
|------|------------------|--------|-----------|-------|---------------|-----------------|
| `autocannon.tres` | Bullet.tscn | 8  | 6   | 45 | 0   | 16 |
| `rocket.tres`     | Rocket.tscn | 40 | 0.8 | 28 | 3.5 | – |
| `twin_cannon.tres` (unlock) | Bullet.tscn | 7 | 9 | 50 | 0 | 18 (projectiles_per_shot 2, spread 4) |

**Upgrades** (`res://data/upgrades/`, these appear in the shop automatically)

| File | category | target_stat | value | mode | base_cost | max_tier |
|------|----------|-------------|-------|------|-----------|----------|
| `engine_turbo.tres`    | ENGINES | top_speed | 2.5 | FLAT | 40 | 5 |
| `engine_torque.tres`   | ENGINES | acceleration | 4 | FLAT | 35 | 5 |
| `nitro_tank.tres`      | ENGINES | boost_capacity | 25 | FLAT | 50 | 3 |
| `armor_plating.tres`   | ARMOR | max_health | 25 | FLAT | 45 | 5 |
| `reactive_armor.tres`  | ARMOR | armor | 15 | FLAT | 60 | 4 |
| `grippy_tires.tres`    | TIRES | grip | 2 | FLAT | 30 | 4 |
| `drift_tires.tres`     | TIRES | drift_factor | 0.03 | FLAT | 30 | 3 |
| `hot_rounds.tres`      | WEAPONS | weapon_damage_multiplier | 0.15 | FLAT | 50 | 5 |
| `rapid_loader.tres`    | WEAPONS | fire_rate_multiplier | 0.1 | PERCENT | 50 | 5 |
| `twin_cannon_unlock.tres` | WEAPONS | none | 0 | FLAT | 150 | 1 (weapon_unlock = twin_cannon.tres, weapon_slot = "turret", visual_scene = TwinCannonMesh.tscn, visual_attach_point = "RoofMount") |

**Waves** go directly on a WaveSpawner: `waves` > Add Element > New WaveData > `groups` > New
SpawnGroup > set enemy_scene + count.

---

## 9. How the pieces talk

- **PlayerData** stores stats, health and scrap. It emits `health_changed`, `scrap_changed`, `stats_changed` and `player_died`.
- **GameManager** handles scene flow. A run starts at a NEW_RUN teleporter (Garage) and ends at a GARAGE teleporter (exit room) or when you die. Dying loses 50 % of the scrap found that run (`death_scrap_penalty`).
- **ArenaRoom**: entering locks the doors and starts the WaveSpawner. `all_waves_completed` unlocks the doors, drops scrap/crates and marks the room CLEARED.
- **ShopUI**: Buy checks the cost, then `PlayerData.apply_upgrade()` deducts scrap, adds the stat modifier, equips the weapon and saves. **GarageHub** then calls `PlayerVehicle.refresh_attachments()`, which reloads the weapons and attaches the new meshes.
- The save file is `user://torque_tombs_save.json`. Settings are in `user://settings.cfg`.

## 10. Tuning tips

- The buggy feels floaty: raise `gravity_multiplier` on PlayerVehicle.
- Drifts are too slidey: lower `drift_factor` (a PlayerData base stat) or raise `grip`.
- You can't clear the lava gap: raise the BoostPad's `boost_speed`, or give it a small `vertical_speed`.
- Enemies stand still: bake a NavigationRegion3D in each room. Without one they drive straight at you, which works in open arenas but not in mazes.
- The turret ignores enemies: check that the DetectionArea mask includes layer 3 and the enemies are on layer 3.
