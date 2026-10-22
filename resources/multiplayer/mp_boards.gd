extends Node
const AUTHOR := "lionrealone"

const SCAN := 0.5
const SEND_DELAY := 0.3
const PIECE := 1000
const MAX_RAW := 4 << 20
const KEY_SLACK := 0.25

var mp: Node
var world: Node
var builds: Node
var _scan_t := 0.0
var _watched := {}
var _due := {}
var _known := {}
var _applying := false
var _parts := {}
var _next := 0

func start(mp_node: Node, world_node: Node) -> void:
	mp = mp_node
	world = world_node
	builds = world.get("builds")

func shutdown() -> void:
	_due.clear()
	_parts.clear()

func _boards() -> Array:
	if builds == null or not is_instance_valid(builds):
		return []
	var arr: Variant = builds.get("paint_boards")
	return arr if arr is Array else []

func _key(b: Node3D) -> String:
	var p := b.global_position
	return "%.2f,%.2f,%.2f" % [p.x, p.y, p.z]

func _process(delta: float) -> void:
	if mp == null or not mp.active() or multiplayer.multiplayer_peer == null:
		return
	_scan_t += delta
	if _scan_t >= SCAN:
		_scan_t = 0.0
		for b in _boards():
			if is_instance_valid(b) and b.has_signal("drawing_changed"):
				var id: int = b.get_instance_id()
				if not _watched.has(id):
					_watched[id] = true
					b.drawing_changed.connect(_on_changed.bind(b))
	for b in _due.keys():
		_due[b] = float(_due[b]) - delta
		if float(_due[b]) <= 0.0:
			_due.erase(b)
			if is_instance_valid(b):
				_send(b, 0)

func _on_changed(b: Node) -> void:
	if _applying or not is_instance_valid(b):
		return

	if int(b.get("showing")) >= 0 and not bool(b.get("drafting")):
		return

	_due[b] = SEND_DELAY

func _send(b: Node, pid: int) -> void:
	var strokes: Array = b.get("strokes")
	var h := hash(strokes)
	if pid == 0 and int(_known.get(b.get_instance_id(), 0)) == h:
		return
	_known[b.get_instance_id()] = h
	var raw := var_to_bytes(strokes)
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	_next += 1
	var id := multiplayer.get_unique_id() * 100000 + _next
	var n := int(ceil(float(packed.size()) / PIECE))
	for i in maxi(n, 1):
		var piece := packed.slice(i * PIECE, mini((i + 1) * PIECE, packed.size()))
		if pid > 0:
			mp._rx_board.rpc_id(pid, _key(b as Node3D), id, i, maxi(n, 1), raw.size(), piece)
		else:
			mp._rx_board.rpc(_key(b as Node3D), id, i, maxi(n, 1), raw.size(), piece)

func send_all(pid: int) -> void:
	for b in _boards():
		if is_instance_valid(b) and not (b.get("strokes") as Array).is_empty():
			_send(b, pid)

func on_piece(key: String, id: int, i: int, n: int, raw_size: int, piece: PackedByteArray) -> void:
	if n <= 0 or n > 4096 or raw_size <= 0 or raw_size > MAX_RAW:
		return
	var slot := "%s|%d" % [key, id]
	var e: Dictionary = _parts.get(slot, {"n": n, "raw": raw_size, "got": {}})
	(e["got"] as Dictionary)[i] = piece
	_parts[slot] = e
	if (e["got"] as Dictionary).size() < n:
		return
	_parts.erase(slot)
	var packed := PackedByteArray()
	for k in n:
		if not (e["got"] as Dictionary).has(k):
			return
		packed.append_array((e["got"] as Dictionary)[k])
	var strokes: Variant = bytes_to_var(packed.decompress(raw_size, FileAccess.COMPRESSION_ZSTD))
	if not (strokes is Array):
		return
	var b := _board_at(key)
	if b == null:
		return
	_known[b.get_instance_id()] = hash(strokes)
	_applying = true
	b.set_picture(strokes)
	_applying = false

func _board_at(key: String) -> Node:
	var xyz := key.split(",")
	if xyz.size() != 3:
		return null
	var at := Vector3(float(xyz[0]), float(xyz[1]), float(xyz[2]))
	var best: Node = null
	var best_d := KEY_SLACK * KEY_SLACK
	for b in _boards():
		if not is_instance_valid(b):
			continue
		var d := (b as Node3D).global_position.distance_squared_to(at)
		if d < best_d:
			best_d = d
			best = b
	return best
