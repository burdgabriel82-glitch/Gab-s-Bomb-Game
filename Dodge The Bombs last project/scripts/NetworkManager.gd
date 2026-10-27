extends Node

const PORT := 4242

var peer: ENetMultiplayerPeer

func host_game() -> void:
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, 2)
	if err != OK:
		print("Failed to host game: ", err)
		return
	
	multiplayer.multiplayer_peer = peer
	print("Hosting LAN game on port: ", PORT)

func join_game(ip: String) -> void:
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, PORT)
	if err != OK:
		print("Failed to join game: ", err)
		return
	
	multiplayer.multiplayer_peer = peer
	print("Joining LAN game at: ", ip, ":", PORT)
