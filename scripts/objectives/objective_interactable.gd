extends "res://scripts/interaction/interactable.gd"
## Interactable driven by callables, so one subclass serves pillars, panels, relief, lever and viewpoint.
## `interact_callable(player) -> bool`, `enabled_callable(player) -> bool`, `prompt_callable() -> String`.

var interact_callable: Callable
var enabled_callable: Callable
var prompt_callable: Callable


func can_interact(player: Node) -> bool:
	if enabled_callable.is_valid():
		return bool(enabled_callable.call(player))
	return true


func get_prompt() -> String:
	if prompt_callable.is_valid():
		return String(prompt_callable.call())
	return prompt_text


func interact(player: Node) -> bool:
	if not can_interact(player) or not interact_callable.is_valid():
		return false
	return bool(interact_callable.call(player))
