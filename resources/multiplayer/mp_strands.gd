extends Node
const AUTHOR := "lionrealone"

const SCAN_TICK := 0.1
const MOVE_TICK := 0.1
const CENSUS_TICK := 5.0
const RANGE := 26.0
const MOVE_EPS := 0.004
const ADD_BUDGET := 80
const MOVE_BUDGET := 120
const MINE_CAP := 400
const MAX_RAW := 4 << 20

var mp: Node
var world: Node
var live: Node

var _mine := {}
var _ghost := {}
var _sent := {}
var _owner := {}
var _goal := {}
var _next := 0
var _watched := {}
var _scan_t := 0.0
var _move_t := 0.0
var _census_t := 0.0

func start(mp_node: Node, world_node: Node) -> void:
	mp = mp_node
	world = world_node
	live = world.get("live")

func shutdown() -> void:
	for sid in _ghost:
		var b: Variant = _ghost[sid]
		if b != null and is_instance_valid(b) and live != null:
			_revive(b)
			live.consume(b)
	_ghost.clear()
	for pid in _hands:
		for b in _hands[pid]:
			if b != null and is_instance_valid(b) and live != null:
				_revive(b)
				live.consume(b)
	_hands.clear()
	_mine.clear()
	_sent.clear()
	_owner.clear()

func _me() -> int:
	return multiplayer.get_unique_id()

func _watch(b: Node) -> void:
	var id := b.get_instance_id()
	if _watched.has(id):
		return
	_watched[id] = true
	b.tree_exiting.connect(_on_body_left.bind(b))

func _on_body_left(b: Node) -> void:
	if not is_instance_valid(b):
		return
	var gid := int(b.get_meta("mp_gid", 0))
	if gid != 0 and _ghost.get(gid) == b:
		_ghost.erase(gid)
		_goal.erase(gid)
		_owner.erase(gid)
	var sid := int(b.get_meta("mp_sid", 0))
	if sid != 0 and _mine.get(sid) == b:
		_mine.erase(sid)
		_sent.erase(sid)
		if mp != null and mp.active() and multiplayer.multiplayer_peer != null:
			mp._rx_straw_del.rpc(PackedInt64Array([sid]))
	for pid in _hands:
		(_hands[pid] as Array).erase(b)

	for key in ["mp_ghost", "mp_gid", "mp_sid"]:
		if b.has_meta(key):
			b.remove_meta(key)

func _new_sid() -> int:
	_next += 1
	return _me() * 1000000 + _next

func _process(delta: float) -> void:
	if live == null or not is_instance_valid(live):
		return

	_park_hands()
	_ease(delta)
	_watch_hand()
	if mp == null or not mp.active() or multiplayer.multiplayer_peer == null:
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_scan_t += delta
	if _scan_t >= SCAN_TICK:
		_scan_t = 0.0
		_scan()
	_move_t += delta
	if _move_t >= MOVE_TICK:
		_move_t = 0.0
		_send_moves()
	_census_t += delta
	if _census_t >= CENSUS_TICK:
		_census_t = 0.0
		_census()

func _watchers() -> Array:
	var out: Array = []
	var ws: Node = mp.world_sync
	if ws == null or not is_instance_valid(ws):
		return out
	for id in ws.avatars:
		var a: Variant = ws.avatars[id]
		if a != null and is_instance_valid(a) and (a as Node3D).is_inside_tree():
			out.append((a as Node3D).global_position)
	return out

func _near(at: Vector3, watchers: Array) -> bool:
	for w in watchers:
		if at.distance_squared_to(w) < RANGE * RANGE:
			return true
	return false

func _scan() -> void:
	var watchers := _watchers()
	var active: Variant = live.get("_active")
	if not (active is Array):
		return
	var adds: Array = []
	var seen := {}
	if not watchers.is_empty():
		for b in active:
			if _mine.size() + adds.size() >= MINE_CAP:
				break
			if b == null or not is_instance_valid(b):
				continue
			if b.has_meta("mp_ghost") or b.has_meta("needle_index"):
				continue

			if bool(b.get_meta("protected", false)):
				continue
			var body := b as Node3D
			if not body.is_inside_tree() or not _near(body.global_position, watchers):
				continue
			var sid := int(b.get_meta("mp_sid", 0))
			if sid != 0 and _mine.get(sid) == b:
				seen[sid] = true
				continue
			sid = _new_sid()
			b.set_meta("mp_sid", sid)
			_mine[sid] = b
			_watch(b)
			seen[sid] = true
			_sent[sid] = body.global_transform
			adds.append([sid, body.global_transform,
				b.get_meta("tint", Color(1, 1, 1))])
			if adds.size() >= ADD_BUDGET:
				break
	var drop := PackedInt64Array()
	for sid in _mine.keys():
		if seen.has(sid):
			continue
		var b: Variant = _mine[sid]
		_mine.erase(sid)
		_sent.erase(sid)
		if b != null and is_instance_valid(b):
			b.remove_meta("mp_sid")
		drop.append(sid)
	if not adds.is_empty():
		mp._rx_straw_add.rpc(adds)
	if drop.size() > 0:
		mp._rx_straw_del.rpc(drop)

func _send_moves() -> void:
	if _mine.is_empty():
		return
	var ids := PackedInt64Array()
	var rows := PackedFloat32Array()
	for sid in _mine:
		var b: Variant = _mine[sid]
		if b == null or not is_instance_valid(b) or not (b as Node3D).is_inside_tree():
			continue
		var xf: Transform3D = (b as Node3D).global_transform
		var was: Variant = _sent.get(sid)
		if was != null and (was as Transform3D).origin.distance_squared_to(xf.origin) < MOVE_EPS * MOVE_EPS:
			continue
		_sent[sid] = xf
		ids.append(sid)
		var q := xf.basis.get_rotation_quaternion()
		rows.append_array(PackedFloat32Array([xf.origin.x, xf.origin.y, xf.origin.z,
			q.x, q.y, q.z, q.w]))
		if ids.size() >= MOVE_BUDGET:
			break
	if ids.size() > 0:
		mp._rx_straw_move.rpc(ids, rows)

func _census() -> void:
	var ids := PackedInt64Array()
	for sid in _mine:
		if is_instance_valid(_mine[sid]):
			ids.append(sid)
	mp._rx_straw_census.rpc(ids)

func on_add(sender: int, adds: Array) -> void:
	if live == null or not is_instance_valid(live):
		return
	for row in adds:
		if not (row is Array) or (row as Array).size() < 3:
			continue
		var sid: int = row[0]
		if _ghost.has(sid) or _mine.has(sid):
			continue
		var xf: Transform3D = row[1]
		var b: Variant = live.spawn(xf.origin, xf.basis, Vector3.ZERO, row[2], true)
		if b == null:
			continue
		b.set_meta("mp_ghost", true)
		b.set_meta("mp_gid", sid)
		_solid(b)
		_place(b, xf)
		_ghost[sid] = b
		_owner[sid] = sender
		_watch(b)

func on_move(ids: PackedInt64Array, rows: PackedFloat32Array) -> void:
	for i in ids.size():
		var b: Variant = _ghost.get(ids[i])
		if b == null or not is_instance_valid(b) or not (b as Node3D).is_inside_tree():
			continue
		var k := i * 7
		if k + 6 >= rows.size():
			return
		var to := Transform3D(
			Basis(Quaternion(rows[k + 3], rows[k + 4], rows[k + 5], rows[k + 6])),
			Vector3(rows[k], rows[k + 1], rows[k + 2]))
		_goal[ids[i]] = [(b as Node3D).global_transform, to, 0.0]

func on_del(ids: PackedInt64Array) -> void:
	for sid in ids:
		_drop_ghost(sid)

func on_census(sender: int, ids: PackedInt64Array) -> void:
	var theirs := {}
	for sid in ids:
		theirs[sid] = true
	var gone: Array = []
	for sid in _ghost:
		if int(_owner.get(sid, 0)) == sender and not theirs.has(sid):
			gone.append(sid)
	for sid in gone:
		_drop_ghost(sid)

func _drop_ghost(sid: int) -> void:
	var b: Variant = _ghost.get(sid)
	_ghost.erase(sid)
	_goal.erase(sid)
	_owner.erase(sid)
	if b != null and is_instance_valid(b) and live != null:
		_revive(b)
		live.consume(b)

func _revive(b: Node) -> void:
	var body := b as Node3D
	if body == null or not body.is_inside_tree():
		return
	var space: RID = body.get_world_3d().space
	PhysicsServer3D.body_set_space(b.get_rid(), space)
	PhysicsServer3D.body_set_state(b.get_rid(),
		PhysicsServer3D.BODY_STATE_TRANSFORM, body.global_transform)
	body.force_update_transform()

func peer_gone(pid: int) -> void:
	var gone: Array = []
	for sid in _owner:
		if int(_owner[sid]) == pid:
			gone.append(sid)
	for sid in gone:
		_drop_ghost(sid)

const HAND_FAN := 0.05

const HAND_REACH := 0.13
const HAND_DROP := -0.03

var _hands := {}

func set_hand(pid: int, count: int) -> void:
	if live == null or not is_instance_valid(live):
		return
	var held: Array = _hands.get(pid, [])
	count = clampi(count, 0, 12)
	while held.size() > count:
		var b: Variant = held.pop_back()
		if b != null and is_instance_valid(b):
			_revive(b)
			live.consume(b)
	while held.size() < count:
		var b: Variant = live.spawn(Vector3.ZERO, Basis(), Vector3.ZERO,
			Color(0.86, 0.74, 0.4), true)
		if b == null:
			break
		b.set_meta("mp_ghost", true)
		held.append(b)
		_watch(b)
	if held.is_empty():
		_hands.erase(pid)
	else:
		_hands[pid] = held

func _park_hands() -> void:
	if _hands.is_empty():
		return
	var ws: Node = mp.world_sync
	if ws == null or not is_instance_valid(ws):
		return
	for pid in _hands.keys():
		var av: Variant = ws.avatars.get(pid)
		if av == null or not is_instance_valid(av) or not av.has_method("hand_xform"):
			set_hand(int(pid), 0)
			continue
		var base: Transform3D = av.hand_xform()
		var held: Array = _hands[pid]
		for i in held.size():
			var b: Variant = held[i]
			if b == null or not is_instance_valid(b) or not (b as Node3D).is_inside_tree():
				continue
			var side := (float(i) - float(held.size() - 1) * 0.5) * HAND_FAN
			var xf := base * Transform3D(Basis(Vector3.UP, side * 1.6),
				Vector3(side, HAND_DROP, -HAND_REACH))
			(b as Node3D).global_transform = xf

func drop_hand(pid: int) -> void:
	set_hand(pid, 0)

func _solid(b: Node) -> void:
	_revive(b)
	b.collision_layer = Cfg.L_STRAND
	b.collision_mask = 0
	b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	b.freeze = true
	b.continuous_cd = false

func _place(b: Node, xf: Transform3D) -> void:
	PhysicsServer3D.body_set_state(b.get_rid(),
		PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	(b as Node3D).global_transform = xf

func _watch_hand() -> void:
	if _ghost.is_empty():
		return
	var pl: Variant = world.get("player")
	if pl == null or not is_instance_valid(pl):
		return
	var hand: Variant = pl.get("hand")
	if hand == null or not is_instance_valid(hand) or not hand.has_method("held_bodies"):
		return
	for b in hand.held_bodies():
		if b == null or not is_instance_valid(b) or not b.has_meta("mp_ghost"):
			continue
		var sid := int(b.get_meta("mp_gid", 0))
		if sid == 0 or not _ghost.has(sid):
			continue
		_ghost.erase(sid)
		_goal.erase(sid)
		_owner.erase(sid)
		b.remove_meta("mp_ghost")
		b.remove_meta("mp_gid")

		b.collision_mask = LiveStrandManager.STRAND_MASK
		b.continuous_cd = true
		mp._rx_straw_claim.rpc(sid)

func host_take(b: Variant) -> bool:
	if not mp.is_host or b == null or not is_instance_valid(b):
		return false
	var sid := int((b as Node).get_meta("mp_gid", 0))
	if sid == 0 or _ghost.get(sid) != b:
		return false
	_ghost.erase(sid)
	_goal.erase(sid)
	_owner.erase(sid)
	b.remove_meta("mp_ghost")
	b.remove_meta("mp_gid")

	b.set_meta(LiveStrandManager.META_PROTECTED, false)
	b.collision_mask = LiveStrandManager.STRAND_MASK
	b.continuous_cd = true
	b.freeze = false
	b.sleeping = false
	mp._rx_straw_claim.rpc(sid)
	return true

func on_claim(sender: int, sid: int) -> void:
	if sender == _me():
		return
	var mine: Variant = _mine.get(sid)
	if mine != null:
		_mine.erase(sid)
		_sent.erase(sid)
		if is_instance_valid(mine) and live != null:
			if mine.has_meta("mp_sid"):
				mine.remove_meta("mp_sid")
			live.consume(mine)
		return
	_drop_ghost(sid)

func _ease(delta: float) -> void:
	if _goal.is_empty():
		return
	var step_t := delta / MOVE_TICK
	var done: Array = []
	for sid in _goal:
		var b: Variant = _ghost.get(sid)
		if b == null or not is_instance_valid(b) or not (b as Node3D).is_inside_tree():
			done.append(sid)
			continue
		var walk: Array = _goal[sid]
		var from: Transform3D = walk[0]
		var to: Transform3D = walk[1]
		var t: float = minf(1.0, float(walk[2]) + step_t)
		walk[2] = t
		_place(b, Transform3D(
			Basis(from.basis.get_rotation_quaternion().slerp(
				to.basis.get_rotation_quaternion(), t)),
			from.origin.lerp(to.origin, t)))
		if t >= 1.0:
			done.append(sid)
	for sid in done:
		_goal.erase(sid)
