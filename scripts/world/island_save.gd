extends RefCounted
## Versioned local save for the island. JSON only (never var_to_str / bytes_to_var / objects from disk).
## Root: {version:int, island_seed:int, procedural:bool, session:Dictionary, player:{hp:int, stamina:float, potions:int}}.
## session = SessionProgress.export_state(). On disk island_seed is a decimal string (no float precision loss).
## Save policy: always the last checkpoint (never mid-swing); the player is placed at session.checkpoint_transform.
## Write safety: tmp file -> rename over the save; the previous valid save is never removed before the replacement
## succeeded (fallback keeps it as .bak and restores it on failure). Reads fall back to .bak if the main file is invalid.

const VERSION := 1
const MAX_BYTES := 1048576
const MAX_DEPTH := 5
const MAX_ENTRIES := 512
const MAX_RESOURCE := 100000.0
const KEY_SOCKETS := &"gatekeeper_sockets"
const KEY_STARTED := &"gatekeeper_started"
const KEY_SNAPSHOT := &"gatekeeper_snapshot"
const KEY_DEFEATED := &"gatekeeper_defeated"
const KEY_GATE_OPEN := &"gatekeeper_gate_open"
## Boolean puzzle flags written by the objective modules and the gatekeeper.
const BOOL_KEYS: Array[StringName] = [&"symbol_pillars", &"energy_path", &"summit_shortcut", KEY_STARTED, KEY_DEFEATED, KEY_GATE_OPEN]
const SOCKET_IDS: Array[StringName] = [&"forest_artifact", &"energy_artifact", &"summit_artifact"]
const PICKUP_KINDS: Array[StringName] = [&"potion", &"artifact"]

## Overridable so tests never touch the real save.
static var save_path := "user://island_save.json"


static func _tmp() -> String:
	return save_path + ".tmp"


static func _bak() -> String:
	return save_path + ".bak"


## True only for a valid, loadable save.
static func has_save() -> bool:
	return not read_save().is_empty()


## Validated root dictionary (island_seed int, boss snapshot numbers normalized), or {} when missing/corrupt/invalid.
static func read_save() -> Dictionary:
	var root := _load(save_path)
	if root.is_empty():
		root = _load(_bak())
	return root


static func write_save(data: Dictionary) -> Error:
	var root := _validate_root(data)
	if root.is_empty():
		return ERR_INVALID_DATA
	var out := root.duplicate()
	out["island_seed"] = str(root["island_seed"])
	var file := FileAccess.open(_tmp(), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(out))
	var werr := file.get_error()
	file.close()
	if werr != OK:
		DirAccess.remove_absolute(_tmp())
		return werr
	if _load(_tmp()).is_empty():
		DirAccess.remove_absolute(_tmp())
		return ERR_FILE_CORRUPT
	var err := DirAccess.rename_absolute(_tmp(), save_path)
	if err != OK and FileAccess.file_exists(save_path):
		# Rename does not replace here: park the old save as .bak, install the new one, restore the old on failure.
		err = DirAccess.rename_absolute(save_path, _bak())
		if err == OK:
			err = DirAccess.rename_absolute(_tmp(), save_path)
			if err != OK:
				DirAccess.rename_absolute(_bak(), save_path)
	if err != OK:
		DirAccess.remove_absolute(_tmp())
		return err
	if FileAccess.file_exists(_bak()):
		DirAccess.remove_absolute(_bak())
	return OK


static func clear_save() -> Error:
	var err := OK
	for path in [save_path, _tmp(), _bak()]:
		if FileAccess.file_exists(path):
			var e := DirAccess.remove_absolute(path)
			if e != OK:
				err = e
	return err


static func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}
	return _validate_root(json.data)


# ---- Codec (pure) ----

static func encode_transform(t: Transform3D) -> Array:
	var b := t.basis
	var o := t.origin
	return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, o.x, o.y, o.z]


## Null when malformed (wrong size/type, non-finite, degenerate basis).
static func decode_transform(raw: Variant) -> Variant:
	if not (raw is Array) or raw.size() != 12:
		return null
	for v in raw:
		if not _is_num(v):
			return null
	var f: Array = raw
	var t := Transform3D(
		Basis(Vector3(f[0], f[1], f[2]), Vector3(f[3], f[4], f[5]), Vector3(f[6], f[7], f[8])),
		Vector3(f[9], f[10], f[11]))
	if absf(t.basis.determinant()) < 0.0001:
		return null
	return t


## JSON-friendly copy of puzzle_progress (StringName -> String keys).
static func encode_progress(progress: Dictionary) -> Dictionary:
	var out := {}
	for k in progress:
		var v: Variant = _clean_value(progress[k], 0)
		if v != null:
			out[String(k)] = v
	return out


## Runtime puzzle_progress from encoded data, semantically validated against the real modules:
## only known keys; flags are bool; sockets = {known artifact id: true}; gatekeeper_started requires a valid
## snapshot {hp:int>=1, stamina:float>=0, potions:int>=0}; a snapshot without started or with defeated is rejected
## (the gatekeeper erases it on victory). Null on any violation (transactional: caller assigns nothing).
static func decode_progress(raw: Variant) -> Variant:
	if not (raw is Dictionary):
		return null
	var out := {}
	for k in raw:
		if not (k is String):
			return null
		var key := StringName(k)
		var v: Variant = raw[k]
		if key in BOOL_KEYS:
			if not (v is bool):
				return null
			out[key] = v
		elif key == KEY_SOCKETS:
			if not (v is Dictionary):
				return null
			var sockets := {}
			for sid in v:
				if not (sid is String) or not (StringName(sid) in SOCKET_IDS) or v[sid] != true:
					return null
				sockets[StringName(sid)] = true
			out[key] = sockets
		elif key == KEY_SNAPSHOT:
			var snap: Variant = _decode_snapshot(v)
			if snap == null:
				return null
			out[key] = snap
		else:
			return null
	var started: bool = out.get(KEY_STARTED, false)
	var defeated: bool = out.get(KEY_DEFEATED, false)
	if out.has(KEY_SNAPSHOT) and (not started or defeated):
		return null
	if started and not defeated and not out.has(KEY_SNAPSHOT):
		return null
	return out


static func _decode_snapshot(v: Variant) -> Variant:
	if not (v is Dictionary) or v.size() != 3:
		return null
	for key in ["hp", "stamina", "potions"]:
		if not _is_num(v.get(key)) or absf(float(v[key])) > MAX_RESOURCE:
			return null
	if float(v["hp"]) < 1.0 or float(v["stamina"]) < 0.0 or float(v["potions"]) < 0.0:
		return null
	return {"hp": int(v["hp"]), "stamina": float(v["stamina"]), "potions": int(v["potions"])}


static func _is_num(v: Variant) -> bool:
	return (v is float or v is int) and is_finite(float(v))


static func _clean_value(v: Variant, depth: int) -> Variant:
	if depth > MAX_DEPTH:
		return null
	match typeof(v):
		TYPE_BOOL, TYPE_INT:
			return v
		TYPE_FLOAT:
			return v if is_finite(v) else null
		TYPE_STRING, TYPE_STRING_NAME:
			return String(v)
		TYPE_DICTIONARY:
			if v.size() > MAX_ENTRIES:
				return null
			var d := {}
			for k in v:
				if not (k is String or k is StringName):
					return null
				var c: Variant = _clean_value(v[k], depth + 1)
				if c == null:
					return null
				d[String(k)] = c
			return d
	return null


## Validates an exported session section; returns decoded runtime values or {} when invalid:
## {checkpoint_id:StringName, checkpoint_transform:Transform3D, collected:Dictionary[StringName,StringName],
##  killed:Dictionary[StringName,bool], puzzle_progress:Dictionary}
static func decode_session(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	for key in ["checkpoint_id", "checkpoint_transform", "collected", "killed", "puzzle_progress"]:
		if not raw.has(key):
			return {}
	if not (raw["checkpoint_id"] is String) or raw["checkpoint_id"].length() > 64:
		return {}
	var t: Variant = decode_transform(raw["checkpoint_transform"])
	if t == null:
		return {}
	var collected: Dictionary[StringName, StringName] = {}
	if not (raw["collected"] is Dictionary) or raw["collected"].size() > MAX_ENTRIES:
		return {}
	for id in raw["collected"]:
		var kind: Variant = raw["collected"][id]
		if not (id is String) or id.is_empty() or id.length() > 64 or not (kind is String) or not (StringName(kind) in PICKUP_KINDS):
			return {}
		collected[StringName(id)] = StringName(kind)
	var killed: Dictionary[StringName, bool] = {}
	if not (raw["killed"] is Array) or raw["killed"].size() > MAX_ENTRIES:
		return {}
	for id in raw["killed"]:
		if not (id is String) or id.is_empty() or id.length() > 64:
			return {}
		killed[StringName(id)] = true
	var progress: Variant = decode_progress(raw["puzzle_progress"])
	if progress == null:
		return {}
	return {
		"checkpoint_id": StringName(raw["checkpoint_id"]),
		"checkpoint_transform": t,
		"collected": collected,
		"killed": killed,
		"puzzle_progress": progress,
	}


static func _valid_player(p: Variant) -> bool:
	return p is Dictionary and p.size() == 3 and _decode_snapshot(p) != null


## Root with island_seed as int and normalized player numbers, or {} if invalid. Accepts int or decimal-string seed.
static func _validate_root(data: Dictionary) -> Dictionary:
	for key in ["version", "island_seed", "procedural", "session", "player"]:
		if not data.has(key):
			return {}
	if not _is_num(data["version"]) or int(data["version"]) != VERSION:
		return {}
	var seed_raw: Variant = data["island_seed"]
	var seed_value := 0
	if seed_raw is int:
		seed_value = seed_raw
	elif seed_raw is String and seed_raw.is_valid_int():
		seed_value = int(seed_raw)
	else:
		return {}
	if not (data["procedural"] is bool):
		return {}
	if decode_session(data["session"]).is_empty() or not _valid_player(data["player"]):
		return {}
	return {
		"version": VERSION,
		"island_seed": seed_value,
		"procedural": data["procedural"],
		"session": data["session"],
		"player": _decode_snapshot(data["player"]),
	}
