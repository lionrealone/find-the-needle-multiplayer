extends Node
const AUTHOR := "lionderwahre"

const MOVE_TICK := 0.1
const STATE_TICK := 1.0
const CENSUS_TICK := 6.0
const MOVE_EPS := 0.005
const BASIS_EPS := 0.01
const MOVE_BUDGET := 60
const STATE_BUDGET := 20
const RESET_BATCH := 30
const SMOOTH := 16.0

const TOOL_ITEMS := {"spade": 1, "pitchfork": 2, "broom": 3, "sand_shovel": 4,
	"metal_detector": 5, "yard_vac": 6}
const HELD_TICK := 0.2

const PUSHED_ITEMS := {"wheelbarrow": true}

var mp: Node
var world: Node
var props: Node

var _by_id := {}
var _owner := {}
var _sent := {}
var _hash := {}
var _goal := {}
var _want := {}
var _next := 0
var _ready_map := false
var _busy := false
var _move_t := 0.0
var _state_t := 0.0
var _census_t := 0.0
var _held_t := 0.0
var _hidden := {}
var _held := {}
var _pushed := {}
var _boarded := {}
var _belt_t := 0.0
var _log := OS.get_environment("MP_DEBUG_PROPS") != ""

func start(mp_node: Node, world_node: Node) -> void:
	mp = mp_node
	world = world_node
	props = world.get("props")
	if props == null or not is_instance_valid(props):
		return
	props.item_added.connect(_on_added)
	props.item_removed.connect(_on_removed)
	var carry: Variant = _carry_tool()
	if carry != null:
		carry.carry_changed.connect(_on_carry_changed)
	session_started()

func session_started() -> void:
	if mp.is_host and not _ready_map:
		_adopt_all()
		_ready_map = true

func shutdown() -> void:
	if props == null or not is_instance_valid(props):
		return
	if props.item_added.is_connected(_on_added):
		props.item_added.disconnect(_on_added)
	if props.item_removed.is_connected(_on_removed):
		props.item_removed.disconnect(_on_removed)
	var carry: Variant = _carry_tool()
	if carry != null and carry.carry_changed.is_connected(_on_carry_changed):
		carry.carry_changed.disconnect(_on_carry_changed)
	for id in _by_id:
		var it: Variant = _by_id[id]
		if it != null and is_instance_valid(it):
			_release(it)
			if _hidden.has(id):
				it.collision_layer = int(_hidden[id])
				it.visible = true
	for id in _pushed:
		if is_instance_valid(_pushed[id]):
			_pushed[id].push_item(null)
	_pushed.clear()
	_boarded.clear()
	_held.clear()
	_hidden.clear()
	_by_id.clear()
	_owner.clear()
	_goal.clear()

func _carry_tool() -> Variant:
	var pl: Variant = world.get("player")
	if pl == null or not is_instance_valid(pl):
		return null
	var c: Variant = pl.get("carry")
	if c == null or not is_instance_valid(c) or not c.has_signal("carry_changed"):
		return null
	return c

func _me() -> int:
	return multiplayer.get_unique_id()

func _new_id() -> int:
	_next += 1
	return _me() * 1000000 + _next

func _adopt_all() -> void:
	for item in props.items:
		if is_instance_valid(item) and not item.has_meta("mp_id"):
			_adopt(item, _new_id(), _me())

func _adopt(item: Node, id: int, owner: int) -> void:

	if id / 1000000 == _me():
		_next = maxi(_next, id % 1000000)
	item.set_meta("mp_id", id)
	_by_id[id] = item
	_owner[id] = owner
	_want.erase(id)
	if owner == _me():
		_release(item)
	else:
		_puppet(item)

func _forget(id: int) -> void:
	_hidden.erase(id)
	_held.erase(id)
	_by_id.erase(id)
	_owner.erase(id)
	_sent.erase(id)
	_hash.erase(id)
	_goal.erase(id)

func _puppet(item: Node) -> void:
	item.set_meta("mp_copy", true)
	item.set_meta(PropManager.META_CLAIM, get_instance_id())
	item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	item.freeze = true
	item.set_physics_process(false)

	if item is HayTuft and float(item.get("_emerging")) > 0.0:
		item.set("_emerging", 0.0)
		item.collision_layer = int(item.get("_emerge_layer"))
		item.collision_mask = int(item.get("_emerge_mask"))

func _place(item: Node, xform: Transform3D) -> void:
	PhysicsServer3D.body_set_state(item.get_rid(),
		PhysicsServer3D.BODY_STATE_TRANSFORM, xform)
	item.global_transform = xform

func _release(item: Node) -> void:
	if not item.has_meta("mp_copy"):
		return
	item.remove_meta("mp_copy")
	if item.has_meta(PropManager.META_CLAIM) \
	and int(item.get_meta(PropManager.META_CLAIM)) == get_instance_id():
		item.remove_meta(PropManager.META_CLAIM)
	item.set_physics_process(true)

	if item.is_held():
		item.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	else:
		item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		item.freeze = false

func _mine(id: int) -> bool:
	return int(_owner.get(id, 0)) == _me()

func host_take(item: Variant) -> bool:
	if not mp.is_host or item == null or not is_instance_valid(item):
		return false
	var n := item as Node
	if n == null or not n.has_meta("mp_id"):
		return false
	var id := int(n.get_meta("mp_id"))

	if _mine(id) or bool(_held.get(id, false)):
		return false
	_owner[id] = _me()
	_goal.erase(id)
	_held.erase(id)
	_hash.erase(id)
	_release(n)
	mp._rx_prop_claim.rpc(id)
	return true

func _on_added(item: Node) -> void:
	if _busy or not _ready_map or item.has_meta("mp_id"):
		return
	var id := _new_id()
	_adopt(item, id, _me())
	_sent[id] = item.global_transform
	var st := _state_of(item)
	_hash[id] = st.hash()
	if _log:
		print("[MPPROPS] made %s id=%d at %v" % [item.item_id, id, item.global_position])
	mp._rx_prop_add.rpc(id, String(item.item_id), item.global_transform, st)

func _on_removed(item: Node) -> void:
	if not item.has_meta("mp_id"):
		return
	var id := int(item.get_meta("mp_id"))
	var mine := _mine(id)
	_forget(id)
	if _busy:
		return
	if _log:
		print("[MPPROPS] lost %s id=%d mine=%s" % [item.item_id, id, mine])
	if mine and _boarded.has(id):

		mp._rx_prop_board.rpc_id(1, id, _boarded[id])
		_boarded.erase(id)
	elif mine:
		mp._rx_prop_del.rpc(PackedInt64Array([id]))
	elif mp.is_host:

		mp._rx_prop_claim.rpc(id)
		mp._rx_prop_del.rpc(PackedInt64Array([id]))
	else:

		_want[id] = 0

func _on_carry_changed(item: Variant) -> void:

	_state_t = STATE_TICK
	if item == null or not is_instance_valid(item) or not item.has_meta("mp_id"):
		return
	var id := int(item.get_meta("mp_id"))
	if _mine(id):
		return
	_owner[id] = _me()
	_goal.erase(id)
	_held.erase(id)
	_hash.erase(id)
	_release(item)
	mp._rx_prop_claim.rpc(id)

func _watch_belts() -> void:
	for belt in BeltPath._live:
		if is_instance_valid(belt) and not belt.caught.is_connected(_on_belt_caught):
			belt.caught.connect(_on_belt_caught)

func _on_belt_caught(rb: Node) -> void:
	if rb == null or not is_instance_valid(rb) or not rb.has_meta("mp_id"):
		return
	var id := int(rb.get_meta("mp_id"))
	if _mine(id):
		_boarded[id] = (rb as Node3D).global_transform
		_hand_rider.call_deferred(rb)

func _hand_rider(rb: Node) -> void:
	if rb == null or not is_instance_valid(rb) or not rb.is_inside_tree():
		return
	var id := int(rb.get_meta("mp_id", 0))
	if not _mine(id) or not BeltPath.is_rider(rb as RigidBody3D):
		return
	var xf: Transform3D = _boarded.get(id, (rb as Node3D).global_transform)
	_boarded.erase(id)
	BeltPath.release(rb as RigidBody3D)
	_owner[id] = 1
	_goal.erase(id)
	_hash.erase(id)
	_puppet(rb)
	_place(rb, xf)
	mp._rx_prop_board.rpc_id(1, id, xf)

func on_board(sender: int, id: int, xf: Transform3D) -> void:
	var it: Variant = _by_id.get(id)
	if it == null or not is_instance_valid(it) or int(_owner.get(id, 0)) != sender:
		return

	_held.erase(id)
	if not host_take(it):
		return
	_place(it, xf)
	(it as RigidBody3D).linear_velocity = Vector3.ZERO
	(it as RigidBody3D).sleeping = false

const CLAIM_REACH := 2.4

func _claim_in_reach() -> void:
	var pl: Variant = world.get("player")
	if pl == null or not is_instance_valid(pl):
		return
	var tool := int(pl.get("current_tool"))
	if tool != Player.Tool.SHOVEL or not Input.is_action_pressed("primary"):
		return
	var eye: Vector3 = pl.eye_position()
	var look: Vector3 = pl.look_direction()
	for id in _by_id.keys():
		if _mine(id) or bool(_held.get(id, false)):
			continue
		var it: Variant = _by_id[id]
		if it == null or not is_instance_valid(it) or not (it is HayWad) or not (it as Node3D).is_inside_tree():
			continue

		if BeltPath.is_rider(it as RigidBody3D):
			continue
		var to: Vector3 = (it as Node3D).global_position - eye
		if to.length() > CLAIM_REACH or to.normalized().dot(look) < 0.6:
			continue
		_owner[id] = _me()
		_goal.erase(id)
		_hash.erase(id)
		_release(it)
		mp._rx_prop_claim.rpc(id)

func _state_of(item: Node) -> Dictionary:
	var st: Dictionary = item.to_state()
	if item.holds_needle():
		st["needle"] = item.needle_index

	if item.is_held():
		st["held"] = true
	return st

func _process(delta: float) -> void:
	_smooth(delta)
	_held_t += delta
	if _held_t >= HELD_TICK:
		_held_t = 0.0
		_hide_held_tools()
		_hand_barrows()
	if mp == null or not mp.active() or multiplayer.multiplayer_peer == null:
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if not _ready_map:
		return
	if not mp.is_host:
		_belt_t += delta
		if _belt_t >= 0.5:
			_belt_t = 0.0
			_watch_belts()
	_move_t += delta
	if _move_t >= MOVE_TICK:
		_move_t = 0.0
		_move_tick()
		_claim_in_reach()
	_state_t += delta
	if _state_t >= STATE_TICK:
		_state_t = 0.0
		_state_tick()
	_census_t += delta
	if _census_t >= CENSUS_TICK:
		_census_t = 0.0
		_census_tick()

func _hide_held_tools() -> void:
	var ws: Variant = mp.world_sync if mp != null else null
	var avatars: Dictionary = ws.avatars if ws != null and is_instance_valid(ws) else {}
	for id in _by_id:
		var it: Variant = _by_id[id]
		if it == null or not is_instance_valid(it):
			continue
		var tool: int = TOOL_ITEMS.get(String(it.item_id), 0)
		if tool == 0:
			continue
		var hide := false
		if not _mine(id):
			var av: Variant = avatars.get(int(_owner.get(id, 0)))
			if av != null and is_instance_valid(av) and int(av.get("_tool")) == tool:
				var off: Vector3 = it.global_position - av.global_position
				hide = off.y > 0.5 and Vector2(off.x, off.z).length() < 2.0
		if hide and not _hidden.has(id):

			_hidden[id] = it.collision_layer
			it.collision_layer = 0
			it.visible = false
		elif not hide and _hidden.has(id):
			it.collision_layer = int(_hidden[id])
			_hidden.erase(id)
			it.visible = true

func _hand_barrows() -> void:
	var ws: Variant = mp.world_sync if mp != null else null
	var avatars: Dictionary = ws.avatars if ws != null and is_instance_valid(ws) else {}
	var want := {}
	for pid in avatars:
		var av: Variant = avatars[pid]
		if av == null or not is_instance_valid(av) or not av.has_method("push_item"):
			continue
		for it in held_by(int(pid)):
			if PUSHED_ITEMS.has(String(it.item_id)):
				want[int(it.get_meta("mp_id"))] = av
	for id in _pushed.keys():
		var av: Variant = _pushed[id]
		if is_instance_valid(av) and want.get(id) == av:
			continue
		_pushed.erase(id)

		if is_instance_valid(av) and not want.values().has(av):
			av.push_item(null)
	for id in want:
		if _pushed.has(id):
			continue
		var it: Node = _by_id[id]

		if not _goal.has(id):
			_goal[id] = it.global_transform
		_pushed[id] = want[id]
		want[id].push_item(it)

func held_by(pid: int) -> Array:
	var out: Array = []
	for id in _held:
		var it: Variant = _by_id.get(id)
		if int(_owner.get(id, 0)) == pid and it != null and is_instance_valid(it):
			out.append(it)
	return out

func _smooth(delta: float) -> void:
	if _goal.is_empty():
		return
	var f := minf(1.0, delta * SMOOTH)
	var done: Array = []
	for id in _goal:
		var it: Variant = _by_id.get(id)
		if it == null or not is_instance_valid(it):
			done.append(id)
			continue
		if _pushed.has(id):

			continue
		var want: Transform3D = _goal[id]
		var step: Transform3D = it.global_transform.interpolate_with(want, f)
		_place(it, step)
		if step.origin.distance_to(want.origin) < 0.002:
			_place(it, want)
			done.append(id)
	for id in done:
		_goal.erase(id)

func _move_tick() -> void:
	var ids := PackedInt64Array()
	var xfs: Array = []
	for id in _by_id:
		var it: Variant = _by_id[id]

		if it == null or not is_instance_valid(it) or not _mine(id) or not it.is_inside_tree():
			continue
		var xf: Transform3D = it.global_transform
		var last: Variant = _sent.get(id)
		if last != null and _same(last, xf):
			continue
		_sent[id] = xf
		ids.append(id)
		xfs.append(xf)
		if ids.size() >= MOVE_BUDGET:
			break
	if ids.size() > 0:
		mp._rx_prop_move.rpc(ids, xfs)
	if not _want.is_empty():
		var asking := PackedInt64Array()
		for id in _want:
			asking.append(id)
		_want.clear()
		mp._rx_prop_want.rpc(asking)

func _same(a: Transform3D, b: Transform3D) -> bool:
	if a.origin.distance_squared_to(b.origin) > MOVE_EPS * MOVE_EPS:
		return false
	return a.basis.x.distance_squared_to(b.basis.x) < BASIS_EPS * BASIS_EPS \
		and a.basis.y.distance_squared_to(b.basis.y) < BASIS_EPS * BASIS_EPS

func _state_tick() -> void:
	var ids := PackedInt64Array()
	var states: Array = []
	for id in _by_id:
		var it: Variant = _by_id[id]
		if it == null or not is_instance_valid(it) or not _mine(id):
			continue
		var st := _state_of(it)
		var h := st.hash()
		if int(_hash.get(id, 0)) == h:
			continue
		_hash[id] = h
		ids.append(id)
		states.append(st)
		if ids.size() >= STATE_BUDGET:
			break
	if ids.size() > 0:
		mp._rx_prop_state.rpc(ids, states)

func _census_tick() -> void:
	var ids := PackedInt64Array()
	for id in _by_id:
		if _mine(id) and is_instance_valid(_by_id[id]):
			ids.append(id)
	mp._rx_prop_census.rpc(ids)

func on_add(sender: int, id: int, item_id: String, xf: Transform3D, state: Dictionary) -> void:
	var have: Variant = _by_id.get(id)
	if have != null and is_instance_valid(have):
		_goal[id] = xf
		return
	if not ItemDb.has_item(item_id):
		return
	_busy = true
	var it: Variant = props.spawn(item_id, xf, state)
	_busy = false
	if it != null:
		_adopt(it, id, sender)
		_note_held(id, state)

func on_del(ids: PackedInt64Array) -> void:
	for id in ids:
		if _mine(id):
			continue
		var it: Variant = _by_id.get(id)
		_forget(id)
		if it != null and is_instance_valid(it):
			_busy = true
			props.remove(it)
			_busy = false

func on_move(sender: int, ids: PackedInt64Array, xfs: Array) -> void:
	for i in ids.size():
		var id: int = ids[i]
		if _mine(id):
			continue
		var it: Variant = _by_id.get(id)
		if it == null or not is_instance_valid(it):
			_want[id] = sender
			continue
		if int(_owner.get(id, 0)) != sender:
			_owner[id] = sender
			_puppet(it)
		if it.is_held():
			continue
		_goal[id] = xfs[i]

func on_state(sender: int, ids: PackedInt64Array, states: Array) -> void:
	for i in ids.size():
		var id: int = ids[i]
		if _mine(id):
			continue
		var it: Variant = _by_id.get(id)
		if it == null or not is_instance_valid(it):
			_want[id] = sender
			continue
		var st: Dictionary = states[i]
		it.from_state(st)
		it.needle_index = int(st.get("needle", -1))
		_note_held(id, st)

func _note_held(id: int, st: Dictionary) -> void:
	if st.get("held", false):
		_held[id] = true
	else:
		_held.erase(id)

func on_claim(sender: int, id: int) -> void:
	var it: Variant = _by_id.get(id)
	_owner[id] = sender
	_held.erase(id)
	_sent.erase(id)
	_goal.erase(id)
	if it == null or not is_instance_valid(it):
		return
	if sender == _me():
		_release(it)
	else:
		_puppet(it)

func on_want(sender: int, ids: PackedInt64Array) -> void:
	for id in ids:
		if not _mine(id):
			continue
		var it: Variant = _by_id.get(id)
		if it == null or not is_instance_valid(it):
			continue
		mp._rx_prop_add.rpc_id(sender, id, String(it.item_id),
			it.global_transform, _state_of(it))

func on_census(sender: int, ids: PackedInt64Array) -> void:
	var theirs := {}
	for id in ids:
		theirs[id] = true
	var drop: Array = []
	for id in _by_id:
		if int(_owner.get(id, 0)) == sender and not theirs.has(id):
			drop.append(id)
	for id in drop:
		var it: Variant = _by_id.get(id)
		_forget(id)
		if it != null and is_instance_valid(it):
			_busy = true
			props.remove(it)
			_busy = false
	var missing := PackedInt64Array()
	for id in ids:
		var it2: Variant = _by_id.get(id)
		if it2 == null or not is_instance_valid(it2):
			missing.append(id)
	if missing.size() > 0:
		mp._rx_prop_want.rpc_id(sender, missing)

func send_all(pid: int) -> void:
	var ids := PackedInt64Array()
	var owners := PackedInt32Array()
	var entries: Array = []
	var first := true
	for id in _by_id:
		var it: Variant = _by_id[id]
		if it == null or not is_instance_valid(it) or not it.is_inside_tree():
			continue
		ids.append(id)
		owners.append(int(_owner.get(id, 1)))
		var st := _state_of(it)

		if _held.has(id):
			st["held"] = true
		entries.append({
			"id": String(it.item_id),
			"xform": it.global_transform,
			"state": st,
		})
		if entries.size() >= RESET_BATCH:
			mp._rx_prop_reset.rpc_id(pid, first, ids, owners, entries)
			first = false
			ids = PackedInt64Array()
			owners = PackedInt32Array()
			entries = []
	mp._rx_prop_reset.rpc_id(pid, first, ids, owners, entries)
	mp._rx_prop_reset_end.rpc_id(pid)

func on_reset(first: bool, ids: PackedInt64Array, owners: PackedInt32Array, entries: Array) -> void:
	if first:
		_busy = true
		props.clear()
		_busy = false
		_by_id.clear()
		_owner.clear()
		_sent.clear()
		_hash.clear()
		_goal.clear()
		_want.clear()
		_held.clear()
	for i in ids.size():
		var e: Dictionary = entries[i]
		var item_id: String = e.get("id", "")
		if not ItemDb.has_item(item_id):
			continue
		_busy = true
		var it: Variant = props.spawn(item_id, e.get("xform", Transform3D.IDENTITY), e.get("state", {}))
		_busy = false
		if it != null:
			_adopt(it, ids[i], owners[i])
			_note_held(ids[i], e.get("state", {}))

func on_reset_end() -> void:
	_ready_map = true

func peer_gone(pid: int) -> void:
	for id in _owner:
		if int(_owner[id]) != pid:
			continue
		_owner[id] = 1
		_held.erase(id)
		var it: Variant = _by_id.get(id)
		if it == null or not is_instance_valid(it):
			continue
		if _me() == 1:
			_release(it)
			_sent.erase(id)
