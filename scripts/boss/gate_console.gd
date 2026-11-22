extends "res://scripts/interaction/interactable.gd"
## E-interactable of the Gatekeeper arena: one of the three artifact sockets or the activation altar.
## All rules live in the encounter (single source of truth); this node only forwards the Interactor contract.

## &"socket" (installs `artifact_id`) or &"altar" (starts / restarts the fight).
@export var role: StringName = &"socket"
@export var artifact_id: StringName = &""
@export var display_name := "Artefak"

var encounter: Node


func can_interact(player: Node) -> bool:
	return encounter != null and encounter.can_use_console(self, player)


func get_prompt() -> String:
	return encounter.get_console_prompt(self) if encounter != null else prompt_text


func interact(player: Node) -> bool:
	return encounter != null and encounter.use_console(self, player)
