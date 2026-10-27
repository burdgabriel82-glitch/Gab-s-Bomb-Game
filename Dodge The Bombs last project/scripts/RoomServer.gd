extends Node

const PORT := 4242
const MAX_PLAYERS_PER_ROOM := 4

var rooms: Dictionary = {}

func _ready():
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, 64)
	if err != OK:
		push_error("Room server failed to start on port %d. Error: %s" % [PORT, err])
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Room server listening on port: ", PORT)

func _on_peer_connected(id: int):
	print("Room peer connected: ", id)

func _on_peer_disconnected(id: int):
	print("Room peer disconnected: ", id)
	for room_code in rooms.keys():
		var room = rooms[room_code]
		if room["players"].has(str(id)):
			room["players"].erase(str(id))
			if room["players"].is_empty():
				rooms.erase(room_code)
			else:
				broadcast_room_update(room_code)

@rpc("any_peer", "call_local")
func create_room(code: String, player_name: String, color_index: int):
	var sender_id = multiplayer.get_remote_sender_id()
	if code == "":
		rpc_id(sender_id, "room_error", "Room code required.")
		return
	if rooms.has(code):
		rpc_id(sender_id, "room_error", "Room already exists.")
		return
	var room = {"code": code, "host_id": sender_id, "players": {}}
	room["players"][str(sender_id)] = {"slot": 0, "name": player_name, "color_index": color_index}
	rooms[code] = room
	broadcast_room_update(code)

@rpc("any_peer", "call_local")
func join_room(code: String, player_name: String, color_index: int):
	var sender_id = multiplayer.get_remote_sender_id()
	if not rooms.has(code):
		rpc_id(sender_id, "room_error", "Room not found.")
		return
	var room = rooms[code]
	if room["players"].size() >= MAX_PLAYERS_PER_ROOM:
		rpc_id(sender_id, "room_error", "Room is full.")
		return
	var slot = room["players"].size()
	room["players"][str(sender_id)] = {"slot": slot, "name": player_name, "color_index": color_index}
	broadcast_room_update(code)

@rpc("any_peer", "call_local")
func set_player_color(code: String, slot: int, color_index: int):
	var sender_id = multiplayer.get_remote_sender_id()
	if not rooms.has(code):
		return
	var room = rooms[code]
	if room["players"].has(str(sender_id)):
		var player = room["players"][str(sender_id)]
		player["slot"] = slot
		player["color_index"] = color_index
		broadcast_room_update(code)

@rpc("any_peer", "call_local")
func request_start_match(code: String):
	if rooms.has(code):
		var room = rooms[code]
		for id in room["players"].keys():
			rpc_id(int(id), "room_match_started", code, room["players"])

func broadcast_room_update(code: String):
	if not rooms.has(code):
		return
	var room = rooms[code]
	for id in room["players"].keys():
		rpc_id(int(id), "room_update", code, room["players"])

@rpc("any_peer", "call_local")
func ping():
	var sender_id = multiplayer.get_remote_sender_id()
	rpc_id(sender_id, "pong")

@rpc("any_peer", "call_local")
func pong():
	pass

