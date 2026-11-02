class_name PlayerHealth
extends Node
## Player hit points with invulnerability-frame gating. Mirrors the chaser
## take_damage/is_dead/died/health_changed shape: once-guarded damage with
## signals, so the coordinator can forward death to the run state.

signal health_changed(current: float, maximum: float)
signal died

@export var max_hp := 100.0
@export var invuln_duration := 0.5

## Mirrors the max_hp default above; _init and _ready re-assert from max_hp.
var hp: float = 100.0
var _invuln := 0.0
var _dead := false


func _init() -> void:
	hp = max_hp


func _ready() -> void:
	hp = max_hp


func _is_run_active() -> bool:
	if not is_inside_tree():
		return true
	var node := get_parent()
	while node != null and is_instance_valid(node):
		if node.has_method("is_run_active"):
			return bool(node.call("is_run_active"))
		if "run_active" in node:
			return bool(node.get("run_active"))
		node = node.get_parent()
	return true


func _physics_process(delta: float) -> void:
	if not _is_run_active():
		return
	if _invuln > 0.0:
		_invuln = maxf(_invuln - delta, 0.0)


func is_dead() -> bool:
	return _dead or hp <= 0.0


func get_hp() -> float:
	return hp


func take_damage(amount: float) -> void:
	if not _is_run_active():
		return
	if _dead:
		return
	if amount <= 0.0:
		return
	if _invuln > 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	_invuln = invuln_duration
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_dead = true
		died.emit()


func heal(amount: float) -> void:
	if _dead:
		return
	if amount <= 0.0:
		return
	if hp >= max_hp:
		return
	hp = minf(hp + amount, max_hp)
	health_changed.emit(hp, max_hp)


func restore_full_health() -> void:
	hp = max_hp
	_invuln = 0.0
	_dead = false
	health_changed.emit(hp, max_hp)
