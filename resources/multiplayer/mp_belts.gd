extends Node
const AUTHOR := "lionderwahre"

const TICK := 0.25
const FULL_TICK := 2.0
const MAX_RAW := 8 << 20

var mp: Node
var world: Node
var _t := 0.0
var _since := 0.0
var _last_hash := 0

func start(mp_node: Node, world_node: Node) -> void:
	mp = mp_node
	world = world_node

func shutdown() -> void:
	for item in BeltPath._live:
		if not is_instance_valid(item) or not item.is_inside_tree():
			continue
		if not item._records_held:
			continue
		item._records_held = false
		item._eats = Callable()
		item.run.hold_for = Callable()
		item._sync_run_links()

func _process(delta: float) -> void:
	if mp == null or not mp.is_host or not mp.active():
		return
	if multiplayer.multiplayer_peer == null:
		return
	if mp.players.size() < 2:
		return
	_t += delta
	_since += delta
	if _t < TICK:
		return
	_t = 0.0
	send_all()

func send_all(pid: int = 0) -> void:
	var entries: Array = BeltPath.belts_to_array()

	for e in entries:
		var rows: Array = e.get("records", [])
		for row in rows:
			if row is Dictionary:
				row.erase("xform")
				if row.get("state") is Dictionary and (row["state"] as Dictionary).is_empty():
					row.erase("state")
	var raw := var_to_bytes(entries)
	if pid == 0:
		var h := hash(raw)
		if h == _last_hash and _since < FULL_TICK:
			return
		_last_hash = h
		_since = 0.0
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	if pid > 0:
		mp._rx_belts.rpc_id(pid, packed, raw.size())
	else:
		mp._rx_belts.rpc(packed, raw.size())

func on_belts(packed: PackedByteArray, raw_size: int) -> void:
	if raw_size <= 0 or raw_size > MAX_RAW:
		return
	var raw := packed.decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	var entries: Variant = bytes_to_var(raw)
	if not (entries is Array):
		return
	mp.trace.note("belts begin: %d paths" % (entries as Array).size())
	for item in BeltPath._live:
		if not is_instance_valid(item) or not item.is_inside_tree():
			continue
		item.run.clear()

		if not item._records_held:
			item.hold_records(Callable())

	var got: Dictionary = BeltPath.belts_from_array(entries, null)
	mp.trace.note("belts end")
	if OS.get_environment("MP_DEBUG_PROPS") != "":
		var rows := 0
		for e in entries:
			rows += (e.get("records", []) as Array).size()
		print("[MPBELTS] %d paths, %d rows -> %s" % [entries.size(), rows, got])
