extends Node
const AUTHOR := "lionrealone"

const TICK := 0.5
const FULL_TICK := 3.0

var mp: Node
var world: Node
var _t := 0.0
var _full_t := 0.0
var _last := {}
var _stopped := false

func start(mp_node: Node, world_node: Node) -> void:
	mp = mp_node
	world = world_node

func shutdown() -> void:
	var dd := _director()
	if _stopped and dd != null:
		dd.set_process(true)
	_stopped = false

func _director() -> Node:
	var dd: Variant = world.get("deliveries") if world != null and is_instance_valid(world) else null
	return dd if dd != null and is_instance_valid(dd) else null

func _truck() -> Node:
	var tr: Variant = world.get("truck") if world != null and is_instance_valid(world) else null
	return tr if tr != null and is_instance_valid(tr) else null

func _process(delta: float) -> void:
	if mp == null or not mp.active() or multiplayer.multiplayer_peer == null:
		return
	if not mp.is_host:
		var dd := _director()
		if dd != null and dd.is_processing():
			dd.set_process(false)
			_stopped = true
		return
	if mp.players.size() < 2:
		return
	_t += delta
	_full_t += delta
	if _t < TICK:
		return
	_t = 0.0
	var now := _state()
	if now == _last and _full_t < FULL_TICK:
		return
	_full_t = 0.0
	_last = now
	mp._rx_contract.rpc(now)

func _state() -> Dictionary:
	var tr := _truck()
	return {
		"index": GameState.contract_index,
		"delivered": GameState.contract_delivered,
		"done": GameState.contracts_done.keys(),
		"truck": int(tr.get("state")) if tr != null else -1,
	}

func on_state(s: Dictionary) -> void:
	if mp.is_host:
		return
	var index := int(s.get("index", GameState.contract_index))
	var delivered := int(s.get("delivered", 0))
	var was_index: int = GameState.contract_index
	var was_delivered: int = GameState.contract_delivered
	var tr := _truck()

	if index > was_index:
		var dd := _director()
		if dd != null and dd.get("panel") != null:
			dd.panel.mark_complete(DeliveryBook.title_of(was_index))
		Audio.play("sell_register", -2.0)
		Audio.play_delayed("coins", 0.18, -3.0)
		was_delivered = 0
	GameState.contract_index = index
	GameState.contract_delivered = delivered
	var done := {}
	for id in s.get("done", []):
		done[str(id)] = true

	var theirs: Array = done.keys()
	theirs.sort()
	var ours: Array = []
	for id in GameState.contracts_done:
		ours.append(str(id))
	ours.sort()
	if theirs != ours:
		GameState.contracts_done = done
		GameState.contracts_changed.emit()
	if tr != null:
		_follow_truck(tr, int(s.get("truck", -1)))

		if index == was_index and delivered > was_delivered:
			var want := str(DeliveryBook.contract(index).get("want", ""))
			for i in delivered - was_delivered:
				tr.stack_one(want)
	var dd2 := _director()
	if dd2 != null:
		dd2._restate()

func _follow_truck(tr: Node, want: int) -> void:
	var st := int(tr.get("state"))
	if want < 0 or want == st:
		return
	match want:
		DeliveryTruck.State.ARRIVING:
			tr.arrive()
		DeliveryTruck.State.PARKED:
			if st == DeliveryTruck.State.AWAY:
				tr.snap_parked()
		DeliveryTruck.State.LEAVING, DeliveryTruck.State.AWAY:
			if st == DeliveryTruck.State.ARRIVING:
				tr.snap_parked()
			tr.depart()
