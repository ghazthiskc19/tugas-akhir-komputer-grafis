extends Node3D
## Interaction lab: potion/artifact pickups, checkpoint, death volume; HUD shows prompt and session status.

@onready var _interactor = $Interactor
@onready var _session = $Session
@onready var _player = $Player
@onready var _prompt: Label = $HUD/Prompt
@onready var _status: Label = $HUD/Status


func _process(_delta: float) -> void:
	_prompt.text = _interactor.get_prompt()
	_status.text = "%s • Ramuan: %d/%d" % [_session.get_status(), _player.potion_count, _player.max_potions]
