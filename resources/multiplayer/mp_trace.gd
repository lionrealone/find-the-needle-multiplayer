extends Node
const AUTHOR := "lionrealone"

const PATH := "user://mp_trace.log"
const PREV := "user://mp_trace.prev.log"
const MAX_BYTES := 4 << 20
const TICK := 1.0
const COUNTED := ["straw_move", "straw_add", "straw_del", "straw_census",
	"prop_move", "prop_state", "prop_census", "machines", "machine_fields",
	"belts", "hay", "hay_sums", "state_delta"]

var _f: FileAccess = null
var _t := 0.0
var _frames := 0
var _dirty := false
var _counts := {}

func start(version: String) -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(PATH.get_file()):
		dir.rename(PATH.get_file(), PREV.get_file())
	_open()
	note("start mod %s, engine %s, %s" % [version, Engine.get_version_info().get("string", "?"),
		Time.get_datetime_string_from_system(true)])

func _open() -> void:
	_f = FileAccess.open(PATH, FileAccess.WRITE)

func note(text: String) -> void:
	if _f == null:
		return
	_f.store_line("%d %s" % [Time.get_ticks_msec(), text])
	_f.flush()
	_dirty = true
	if _f.get_length() > MAX_BYTES:

		_f.close()
		_open()
		note("trace restarted (size limit)")

func rx(what: String, from: int, size: int) -> void:
	if COUNTED.has(what):
		_counts[what] = int(_counts.get(what, 0)) + 1
		return
	note("rx %s from %d%s" % [what, from, (" n=%d" % size) if size >= 0 else ""])

func _process(delta: float) -> void:

	if _dirty and _f != null:
		_f.store_line("%d frame" % Time.get_ticks_msec())
		_f.flush()
		_dirty = false
	_frames += 1
	_t += delta
	if _t < TICK:
		return
	var got := ""
	for what in _counts:
		got += " %s=%d" % [what, _counts[what]]
	_counts.clear()
	note("tick fps=%d frame_ms=%.1f nodes=%d%s" % [_frames, 1000.0 * _t / maxf(1.0, _frames),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), got])
	_t = 0.0
	_frames = 0

func _exit_tree() -> void:
	if _f != null:
		note("quit")
		_f.close()
		_f = null
