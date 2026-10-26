class_name WeaponResource
extends Resource
## Data for one weapon. Create .tres files from this (right-click FileSystem > New Resource)
## and assign them to a TurretController / RocketLauncher, or to an UpgradeResource's weapon_unlock.

@export var weapon_name: String = "Autocannon"
@export var icon: Texture2D
## Scene whose root uses Bullet.gd or Rocket.gd.
@export var projectile_scene: PackedScene
@export var damage: float = 8.0
## Shots per second (before PlayerData.fire_rate_multiplier).
@export var fire_rate: float = 6.0
@export var projectile_speed: float = 45.0
@export var projectile_lifetime: float = 1.2
@export_range(1, 12) var projectiles_per_shot: int = 1
@export var spread_degrees: float = 2.0
## > 0 makes Rocket projectiles explode with this radius (Bullets ignore it).
@export var splash_radius: float = 0.0
## Turrets resize their DetectionArea sphere to this radius.
@export var detection_range: float = 16.0
## Turret yaw speed when tracking a target.
@export var turn_speed: float = 10.0
@export var fire_sound: AudioStream
## Optional model instanced under the mount when this weapon is equipped (upgraded guns).
@export var model_scene: PackedScene
