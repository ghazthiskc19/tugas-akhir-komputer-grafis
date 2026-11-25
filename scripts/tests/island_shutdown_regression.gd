extends SceneTree
## Source-only lifecycle probe; no QA save bypass. Each case exits through the real game's shutdown timer.
## C:/Godot/godot.exe --headless --verbose --fixed-fps 60 --path . --script res://scripts/tests/island_shutdown_regression.gd -- --case=window --seed=777
## Cases: menu (existing save unchanged), pause (save active resources), window (close with map open).

const SAVE := preload("res://scripts/world/island_save.gd")
const UI_THEME := preload("res://scripts/ui/ui_theme.gd")
const GAME_SCENE := "res://scenes/world/island_game.tscn"
const SUFFIXES: Array[String] = ["", ".tmp", ".bak"]

var _case := "window"
var _seed := 777
var _checks := 0
var _failures := 0
var _original_save_path := ""
var _scratch_path := ""
var _original_files: Dictionary = {}
var _guarded := false


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--case="):
			_case = argument.trim_prefix("--case=")
		elif argument.begins_with("--seed="):
			_seed = argument.trim_prefix("--seed=").to_int()
	_main.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL shutdown/%s: %s" % [_case, message])


func _main() -> void:
	if not ["menu", "pause", "window"].has(_case):
		printerr("Unknown shutdown case: " + _case)
		quit(1)
		return
	_guard_save()
	create_timer(30.0, true).timeout.connect(_watchdog)
	var game: Node = (load(GAME_SCENE) as PackedScene).instantiate()
	game.island_seed = _seed
	game.start_in_menu = true
	root.add_child(game)
	current_scene = game
	await process_frame
	var ui: Node = game.presentation
	var map: Node = ui.get("_map")
	var effects := root.get_node_or_null(^"CombatVfxHub")
	_check(effects != null, "real pooled VFX hub was created")
	_check(map != null, "generated island map was built")
	var map_texture: WeakRef = weakref(map.get("_texture"))
	var theme_resource: WeakRef = weakref(UI_THEME.theme())
	_check(not (ui.get("_cache") as Dictionary).is_empty(), "probe observes a populated audio cache before shutdown")
	# Prime the persistent fade layer too; this is the same helper used by menu/run transitions.
	await UI_THEME.fade_out(self, 0.0)
	await UI_THEME.fade_in(self, 0.0)
	await process_frame
	_check(root.get_node_or_null(^"UiFade") != null, "shared transition layer was created")
	_check_hint_regions(game, ui)
	var fixture := {
		"version": 1, "island_seed": _seed, "procedural": true,
		"session": game.session.export_state(),
		"player": {"hp": 61, "stamina": 37.0, "potions": 1},
	}
	_check(SAVE.write_save(fixture) == OK, "existing valid disk save fixture was written")
	var menu_bytes := FileAccess.get_file_as_bytes(_scratch_path)
	if _case != "menu":
		ui.begin_play(false)
		game.player.get_node(^"Health").current_health = 73
		game.player.stamina = 41.0
		game.player.potion_count = 2
		if _case == "window":
			ui.call(&"_open_map")
			_check(paused and map.visible, "window closes from a real paused map")
		else:
			game.get_node(^"Camera3D").pause_game()
			_check(paused, "pause-menu quit begins while paused")
	# Directly trigger the production handlers, not a test-only cleanup path.
	if _case == "window":
		game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	else:
		ui.request_quit()
	_check(bool(ui.get("_quitting")), "quit handler accepted shutdown")
	_check((ui.get("_cache") as Dictionary).is_empty(), "audio cache released before node destruction")
	for audio: Node in ui.find_children("*", "AudioStreamPlayer", true, false):
		_check(audio.get("stream") == null and not bool(audio.get("playing")), "audio voice stopped and released its stream")
	var disk := SAVE.read_save()
	if _case == "menu":
		_check(FileAccess.get_file_as_bytes(_scratch_path) == menu_bytes, "menu-only quit preserves existing save bytes")
	else:
		_check(not disk.is_empty(), "active quit leaves a valid disk save")
		if not disk.is_empty():
			_check(disk["player"] == {"hp": 73, "stamina": 41.0, "potions": 2}, "quit saved the exact live resources before teardown")
	await game.tree_exited
	await process_frame
	_check(not is_instance_valid(game), "game root was freed before SceneTree.quit")
	_check(not is_instance_valid(ui) and not is_instance_valid(map), "presentation and map were freed")
	_check(not is_instance_valid(effects), "pooled VFX hub was freed")
	_check(root.get_node_or_null(^"UiFade") == null, "shared fade layer was freed")
	_check(map_texture.get_ref() == null, "generated map texture was released")
	_check(theme_resource.get_ref() == null, "cached theme was released")
	# AudioServer owns its asynchronous playback references; leak-freedom is checked in the verbose engine exit log.
	_check_real_save()
	print("island_shutdown_regression/%s: %d checks, %d failed" % [_case, _checks, _failures])
	if _failures > 0:
		quit(1)
	# Success deliberately does not quit here: the actual game's final timer must end the process.


func _check_hint_regions(game: Node, ui: Node) -> void:
	ui.call(&"_refresh_targets")
	var regions: Dictionary = {}
	for target: Dictionary in game.terrain.get_compass_targets():
		regions[target["label"]] = target["region"]
	var module_count := 0
	for target: Dictionary in ui.get("_targets"):
		if target["node"] == null or not regions.has(target["label"]):
			continue
		module_count += 1
		_check(target["region"] == regions[target["label"]], "%s uses the generated region, not authored lab metadata" % target["label"])
		_check(String(ui.call(&"_objective_text", target, 10.0)).contains("(%s)" % target["region"]), "visible objective hint uses the generated region")
	_check(module_count >= 2, "both generated puzzle modules were checked")


func _guard_save() -> void:
	_original_save_path = SAVE.save_path
	for suffix in SUFFIXES:
		var path := _original_save_path + suffix
		if FileAccess.file_exists(path):
			_original_files[suffix] = FileAccess.get_file_as_bytes(path)
	_scratch_path = "user://island_shutdown_%d.json" % OS.get_process_id()
	SAVE.save_path = _scratch_path
	_guarded = true


func _check_real_save() -> void:
	for suffix in SUFFIXES:
		var path := _original_save_path + suffix
		var existed := _original_files.has(suffix)
		_check(FileAccess.file_exists(path) == existed, "real save existence unchanged: " + suffix)
		if existed:
			_check(FileAccess.get_file_as_bytes(path) == _original_files[suffix], "real save bytes unchanged: " + suffix)


func _watchdog() -> void:
	printerr("FAIL shutdown/%s: normal game shutdown did not quit" % _case)
	quit(1)


func _finalize() -> void:
	if not _guarded:
		return
	SAVE.save_path = _original_save_path
	for suffix in SUFFIXES:
		if FileAccess.file_exists(_scratch_path + suffix):
			DirAccess.remove_absolute(_scratch_path + suffix)
