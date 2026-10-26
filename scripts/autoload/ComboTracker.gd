extends Node
## Autoload singleton "ComboTracker" (register below GameManager).
## Style combo: drifts, air time and kills each add points and +1 to the multiplier. Every trick
## refreshes the combo timer; when it runs out the combo cashes in for
## points x multiplier x scrap_per_point scrap. Getting wrecked loses the combo.

signal combo_changed(multiplier: int, points: float, last_trick: String)
signal combo_timer_changed(time_left: float, window: float)
signal combo_banked(scrap: int, multiplier: int)
signal combo_dropped

## Seconds you have to land the next trick before the combo cashes in.
var combo_window: float = 3.5
var max_multiplier: int = 8
var scrap_per_point: float = 0.08

var drift_points_per_second: float = 8.0
var min_drift_time: float = 0.5
var max_drift_points: float = 40.0
var air_points_per_second: float = 12.0
var min_air_time: float = 0.6
var clean_landing_bonus: float = 5.0
var kill_points: float = 10.0

var points: float = 0.0
var multiplier: int = 0
var time_left: float = 0.0


func _ready() -> void:
	PlayerData.player_died.connect(drop)
	GameManager.run_started.connect(drop)


func _process(delta: float) -> void:
	if time_left <= 0.0:
		return
	time_left -= delta
	combo_timer_changed.emit(maxf(time_left, 0.0), combo_window)
	if time_left <= 0.0:
		bank()


## Combos only count during runs and the tutorial, so the garage can't be farmed.
func is_enabled() -> bool:
	return GameManager.run_active or GameManager.in_tutorial


func add_trick(amount: float, trick: String) -> void:
	if amount <= 0.0 or not is_enabled():
		return
	points += amount
	multiplier = mini(multiplier + 1, max_multiplier)
	time_left = combo_window
	GameManager.register_combo(multiplier)
	combo_changed.emit(multiplier, points, trick)


func register_drift(duration: float) -> void:
	if duration >= min_drift_time:
		add_trick(minf(duration * drift_points_per_second, max_drift_points), "DRIFT %.1fs" % duration)


func register_air(air_time: float, clean_landing: bool) -> void:
	if air_time >= min_air_time:
		var amount := air_time * air_points_per_second + (clean_landing_bonus if clean_landing else 0.0)
		add_trick(amount, ("CLEAN LANDING %.1fs" if clean_landing else "AIR %.1fs") % air_time)


func register_kill() -> void:
	add_trick(kill_points, "KILL")


func get_payout() -> int:
	return int(round(points * multiplier * scrap_per_point))


func is_active() -> bool:
	return points > 0.0


func bank() -> void:
	var scrap := get_payout()
	var banked_multiplier := multiplier
	_reset()
	if scrap > 0:
		GameManager.add_run_scrap(scrap)
		combo_banked.emit(scrap, banked_multiplier)


func drop(_unused: Variant = null) -> void:
	if points > 0.0:
		_reset()
		combo_dropped.emit()


func _reset() -> void:
	points = 0.0
	multiplier = 0
	time_left = 0.0
	combo_changed.emit(0, 0.0, "")
