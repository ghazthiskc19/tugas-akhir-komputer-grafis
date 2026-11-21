extends Node
## Health module. Damage only via apply_damage(); health_changed and dead fire once per real change.

signal health_changed(current: int, maximum: int)
signal dead

@export var max_health := 60

var current_health := 0
var is_dead := false


func _ready() -> void:
	current_health = max_health


## True only when damage was applied. Dead targets and non-positive amounts are ignored.
func apply_damage(amount: int) -> bool:
	if is_dead or amount <= 0:
		return false
	current_health = maxi(current_health - amount, 0)
	var died := current_health == 0
	is_dead = died
	health_changed.emit(current_health, max_health)
	if died:
		dead.emit()
	return true
