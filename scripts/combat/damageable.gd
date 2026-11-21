extends Node
## Health module. Damage only via apply_damage(); health_changed and dead fire once per real change.
## State (current_health, is_dead) is updated before any signal, so handlers may re-enter apply_damage/heal/revive and
## still see a consistent module. `dead` fires at most once per life and is skipped if a handler revived the target.

signal health_changed(current: int, maximum: int)
signal dead

@export var max_health := 60

var current_health := 0
var is_dead := false
var _dead_signaled := false


func _ready() -> void:
	current_health = max_health


## True only when damage was applied. Dead targets and non-positive amounts are ignored.
func apply_damage(amount: int) -> bool:
	if is_dead or amount <= 0:
		return false
	current_health = maxi(current_health - amount, 0)
	if current_health == 0:
		is_dead = true
	health_changed.emit(current_health, max_health)
	if is_dead and not _dead_signaled:
		_dead_signaled = true
		dead.emit()
	return true


## Returns the amount actually restored (0 when dead, full, or non-positive).
func heal(amount: int) -> int:
	if is_dead or amount <= 0 or current_health >= max_health:
		return 0
	var healed := mini(amount, max_health - current_health)
	current_health += healed
	health_changed.emit(current_health, max_health)
	return healed


## Full heal and, if dead, revive (re-arms the `dead` signal). Emits health_changed only when something changed.
func restore_full() -> void:
	var changed := is_dead or current_health != max_health
	current_health = max_health
	is_dead = false
	_dead_signaled = false
	if changed:
		health_changed.emit(current_health, max_health)
