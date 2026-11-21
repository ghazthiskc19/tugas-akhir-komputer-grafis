extends Node3D
## I02 preview scene: Rogue + four KayKit Rig_Medium clips. Preview only, no gameplay.

const SKELETON_PATH := NodePath("Rig_Medium/Skeleton3D")
const MODE_IDLE := &"idle"
const MODE_WALK := &"walk"
const MODE_RUN := &"run"
const MODE_ATTACK := &"attack"

const GENERAL := "res://assets/third_party/kaykit/adventurers/animations/Rig_Medium/Rig_Medium_General.glb"
const MOVEMENT := "res://assets/third_party/kaykit/adventurers/animations/Rig_Medium/Rig_Medium_MovementBasic.glb"
const COMBAT := "res://assets/third_party/kaykit/character_animations/animations/Rig_Medium/Rig_Medium_CombatMelee.glb"

const CLIPS := {
	MODE_IDLE: {"file": GENERAL, "clip": "Idle_A", "loop": true},
	MODE_WALK: {"file": MOVEMENT, "clip": "Walking_A", "loop": true},
	MODE_RUN: {"file": MOVEMENT, "clip": "Running_A", "loop": true},
	MODE_ATTACK: {"file": COMBAT, "clip": "Melee_1H_Attack_Slice_Horizontal", "loop": false},
}

const ERROR_COLOR := Color(0.75, 0.1, 0.1)

@onready var _model: Node3D = $Actor/Rogue
@onready var _player: AnimationPlayer = $Actor/AnimationPlayer
@onready var _status: Label = $ReviewHUD/StatusLabel
@onready var _buttons: Dictionary = {
	MODE_IDLE: $ReviewHUD/ButtonRow/IdleButton,
	MODE_WALK: $ReviewHUD/ButtonRow/WalkButton,
	MODE_RUN: $ReviewHUD/ButtonRow/RunButton,
	MODE_ATTACK: $ReviewHUD/ButtonRow/AttackButton,
}

var _mode: StringName = &""


func _ready() -> void:
	var errors := _build_library()
	if not errors.is_empty():
		var message := "ERROR setup animasi:\n" + "\n".join(errors)
		push_error(message)
		_status.text = message
		_status.add_theme_color_override("font_color", ERROR_COLOR)
		for button: Button in _buttons.values():
			button.disabled = true
		return
	for mode: StringName in _buttons:
		(_buttons[mode] as Button).pressed.connect(_select.bind(mode))
	_player.animation_finished.connect(_on_animation_finished)
	_select(MODE_IDLE)


## Duplicates only the four chosen clips; source imports stay untouched.
## Track paths ("Rig_Medium/Skeleton3D:bone") resolve against the Rogue root (AnimationPlayer.root_node).
func _build_library() -> PackedStringArray:
	var errors := PackedStringArray()
	var skeleton := _model.get_node_or_null(SKELETON_PATH) as Skeleton3D
	if skeleton == null:
		errors.append("Skeleton3D tidak ada di %s" % SKELETON_PATH)
		return errors
	var library := AnimationLibrary.new()
	for mode: StringName in CLIPS:
		var config: Dictionary = CLIPS[mode]
		var clip_name: String = config["clip"]
		var scene := load(config["file"]) as PackedScene
		if scene == null:
			errors.append("Gagal load %s" % config["file"])
			continue
		var source := scene.instantiate()
		var source_player := source.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
		if source_player == null or not source_player.has_animation(clip_name):
			errors.append("Klip %s tidak ada di %s" % [clip_name, config["file"]])
		else:
			var animation := source_player.get_animation(clip_name).duplicate() as Animation
			animation.loop_mode = Animation.LOOP_LINEAR if config["loop"] else Animation.LOOP_NONE
			errors.append_array(_check_tracks(animation, skeleton, clip_name))
			library.add_animation(mode, animation)
		source.free()
	if errors.is_empty():
		_player.add_animation_library(&"", library)
	return errors


func _check_tracks(animation: Animation, skeleton: Skeleton3D, clip_name: String) -> PackedStringArray:
	var errors := PackedStringArray()
	for track in animation.get_track_count():
		var path := animation.track_get_path(track)
		var node_path := NodePath(String(path).get_slice(":", 0))
		var bone := String(path).get_slice(":", 1)
		if _model.get_node_or_null(node_path) != skeleton or skeleton.find_bone(bone) < 0:
			errors.append("%s: track %s tidak cocok dengan Rogue" % [clip_name, path])
	return errors


func _select(mode: StringName) -> void:
	if mode == MODE_ATTACK:
		_player.stop()  # Replay from frame 0 even if attack is already running.
		_player.play(mode)
	else:
		_player.play(mode, 0.12)
	_mode = mode
	_show_status("")


func _on_animation_finished(_anim_name: StringName) -> void:
	# Only a naturally finished attack resets to idle; interrupted/replayed attacks are ignored.
	if _mode == MODE_ATTACK and not _player.is_playing():
		_select(MODE_IDLE)
		_show_status("kembali otomatis dari Serang")


func _show_status(note: String) -> void:
	var config: Dictionary = CLIPS[_mode]
	var playback := "loop di tempat" if config["loop"] else "sekali, lalu kembali ke Idle_A"
	var text := "Klip aktif: %s • %s • preview saja" % [config["clip"], playback]
	if not note.is_empty():
		text += " • " + note
	_status.text = text
