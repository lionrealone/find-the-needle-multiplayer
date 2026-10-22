extends Node
const AUTHOR := "lionrealone"

const APP_ID := 5165210

var available := false
var load_status := ""
var steam: Object = null
var steam_id := 0
var persona := ""
var lobby_id := 0
var lobby_owner := 0

signal lobby_created(ok: bool, id: int)
signal lobby_joined(ok: bool, id: int, reason: String)
signal join_requested(id: int)
signal lobby_members_changed()

func setup(base_dir: String) -> Dictionary:
	if available:
		return {"ok": true, "status": load_status}
	_set_app_id()
	if not ClassDB.class_exists("SteamMultiplayerPeer") and not Engine.has_singleton("Steam"):
		var path := base_dir + "/steam/godotsteam.gdextension"
		if not FileAccess.file_exists(path):
			load_status = "no encuentro %s" % path
			return {"ok": false, "status": load_status}
		var st: int = GDExtensionManager.load_extension(path)
		if st != GDExtensionManager.LOAD_STATUS_OK and st != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
			load_status = "la librería de Steam no cargó (código %d)" % st
			return {"ok": false, "status": load_status}
	if not Engine.has_singleton("Steam"):
		load_status = "la librería cargó pero no registró Steam"
		return {"ok": false, "status": load_status}
	steam = Engine.get_singleton("Steam")

	var res: Variant = steam.call("steamInitEx", APP_ID, false)
	var code := 0
	var verbal := ""
	if res is Dictionary:
		code = int(res.get("status", -1))
		verbal = str(res.get("verbal", ""))
	if code != 0:
		load_status = "Steam no arrancó: %s" % verbal
		return {"ok": false, "status": load_status}
	steam_id = int(steam.call("getSteamID"))
	persona = str(steam.call("getPersonaName"))
	available = true
	load_status = "Steam listo (%s)" % persona
	_tune_networking()
	_connect_signals()
	set_process(true)
	return {"ok": true, "status": load_status}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func _process(_delta: float) -> void:
	if steam != null:
		steam.call("run_callbacks")

const SEND_BUFFER := 8 << 20

func _tune_networking() -> void:
	_set_global("NETWORKING_CONFIG_P2P_TRANSPORT_ICE_ENABLE", "NETWORKING_CONFIG_P2P_TRANSPORT_ICE_DISABLE")
	_set_global("NETWORKING_CONFIG_SEND_BUFFER_SIZE", "", SEND_BUFFER)

func _set_global(key: String, value_name: String, value: int = 0) -> void:
	if not ClassDB.class_has_integer_constant("Steam", key):
		print("[MPMod] steam: no %s in this GodotSteam" % key)
		return
	if value_name != "":
		if not ClassDB.class_has_integer_constant("Steam", value_name):
			print("[MPMod] steam: no %s in this GodotSteam" % value_name)
			return
		value = ClassDB.class_get_integer_constant("Steam", value_name)
	var ok: Variant = steam.call("setGlobalConfigValueInt32", ClassDB.class_get_integer_constant("Steam", key), value)
	print("[MPMod] steam: %s = %d (%s)" % [key, value, "ok" if ok else "refused"])

func _set_app_id() -> void:
	for key in ["SteamAppId", "SteamGameId"]:
		if OS.get_environment(key) == "":
			OS.set_environment(key, str(APP_ID))

func _connect_signals() -> void:
	_link("lobby_created", _on_lobby_created)
	_link("lobby_joined", _on_lobby_joined)
	_link("join_requested", _on_join_requested)
	_link("join_game_requested", _on_join_game_requested)
	_link("lobby_chat_update", _on_lobby_chat_update)
	_link("lobby_invite", _on_lobby_invite)

func _link(sig: String, cb: Callable) -> void:
	if steam.has_signal(sig) and not steam.is_connected(sig, cb):
		steam.connect(sig, cb)

func host_lobby(max_players: int = 8) -> void:

	steam.call("createLobby", 1, max_players)

func join_lobby(id: int) -> void:
	steam.call("joinLobby", id)

func leave_lobby() -> void:
	if lobby_id != 0:
		steam.call("leaveLobby", lobby_id)
		lobby_id = 0
		lobby_owner = 0

func invite_overlay() -> void:
	if lobby_id != 0:
		steam.call("activateGameOverlayInviteDialog", lobby_id)

func lobby_members() -> Array:
	var out: Array = []
	if lobby_id == 0:
		return out
	var n := int(steam.call("getNumLobbyMembers", lobby_id))
	for i in n:
		out.append(int(steam.call("getLobbyMemberByIndex", lobby_id, i)))
	return out

func name_of(id: int) -> String:
	if steam == null:
		return "Jugador"
	return str(steam.call("getFriendPersonaName", id))

func set_lobby_data(key: String, value: String) -> void:
	if lobby_id != 0:
		steam.call("setLobbyData", lobby_id, key, value)

func get_lobby_data(key: String) -> String:
	if lobby_id == 0:
		return ""
	return str(steam.call("getLobbyData", lobby_id, key))

func _on_lobby_created(connect_code: int, id: int) -> void:
	if connect_code == 1:
		lobby_id = id
		lobby_owner = steam_id
		set_lobby_data("game", "find_the_needle_mp")
		set_lobby_data("host", persona)

		steam.call("setRichPresence", "connect", "+connect_lobby %d" % id)
		steam.call("setRichPresence", "steam_display", "#Status_Playing")
		lobby_created.emit(true, id)
	else:
		lobby_created.emit(false, 0)

func _on_join_game_requested(_user: int, connect_string: String) -> void:
	var id := lobby_from_connect(connect_string)
	if id != 0:
		join_requested.emit(id)

static func lobby_from_connect(text: String) -> int:
	var parts := text.split(" ", false)
	for i in parts.size():
		if parts[i] == "+connect_lobby" and i + 1 < parts.size():
			return int(parts[i + 1])
	return 0

func lobby_from_command_line() -> int:
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	return lobby_from_connect(" ".join(args))

func _on_lobby_joined(id: int, _perms: int, _locked: bool, response: int) -> void:
	if response == 1:
		lobby_id = id
		lobby_owner = int(steam.call("getLobbyOwner", id))
		lobby_joined.emit(true, id, "")
	else:
		lobby_joined.emit(false, id, "respuesta %d" % response)

func _on_join_requested(id: int, _friend_id: int) -> void:
	join_requested.emit(id)

func _on_lobby_invite(_inviter: int, id: int, _game: int) -> void:
	join_requested.emit(id)

func _on_lobby_chat_update(_id: int, _changed: int, _making: int, _state: int) -> void:
	lobby_members_changed.emit()

func make_peer() -> MultiplayerPeer:
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		return null
	return ClassDB.instantiate("SteamMultiplayerPeer")
