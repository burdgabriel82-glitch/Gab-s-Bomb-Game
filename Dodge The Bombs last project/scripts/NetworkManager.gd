extends Node

const PORT := 4242

var peer: ENetMultiplayerPeer
var room_code := ""
var is_host := false
var local_slot := 0
var local_color_index := 0
var online_players: Array = []

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func host_game(code: String) -> Error:
	room_code = code
	is_host = true
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, 4)
	if err != OK:
		print("Failed to host online game: ", err)
		return err
	multiplayer.multiplayer_peer = peer
	print("Hosting online room on port: ", PORT, " room: ", room_code)
	return OK

func join_game(ip: String, code: String) -> Error:
	room_code = code
	is_host = false
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, PORT)
	if err != OK:
		print("Failed to join online room: ", err)
		return err
	multiplayer.multiplayer_peer = peer
	print("Joining online room at: ", ip, ":", PORT, " room: ", room_code)
	return OK

func _on_peer_connected(id: int):
	print("Peer connected: ", id)

func _on_peer_disconnected(id: int):
	print("Peer disconnected: ", id)

func _on_connected_to_server():
	print("Connected to room server.")

func _on_connection_failed():
	print("Connection failed.")


