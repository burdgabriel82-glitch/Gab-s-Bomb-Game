extends Node2D

const PLAYER_SCENE = preload("res://scenes/Player.tscn")
const BOMB_SCENE = preload("res://scenes/Bomb.tscn")

const ARENA_WIDTH = 1280
const ARENA_HEIGHT = 720
const MIN_ACTIVE_BOMBS = 100
const MAX_ACTIVE_BOMBS = 30
const ONLINE_PLAYER_LIMIT = 4
const DEFAULT_SERVER_IP = "127.0.0.1"

const COLOR_OPTIONS = [
	{"name": "Red", "color": Color(1.0, 0.32, 0.32)},
	{"name": "Orange", "color": Color(1.0, 0.62, 0.2)},
	{"name": "Yellow", "color": Color(1.0, 0.88, 0.25)},
	{"name": "Green", "color": Color(0.28, 0.88, 0.42)},
	{"name": "Blue", "color": Color(0.26, 0.62, 1.0)},
	{"name": "Indigo", "color": Color(0.38, 0.42, 0.93)},
	{"name": "Violet", "color": Color(0.76, 0.52, 1.0)},
]

enum GameMode {
	SOLO,
	LOCAL_MULTIPLAYER,
	ONLINE_MULTIPLAYER,
}

var world_root: Node2D
var ui_root: CanvasLayer
var game_mode := GameMode.SOLO
var match_started := false
var round_active := false
var elapsed_time := 0.0
var players: Array = []
var bombs: Array = []
var bomb_timer: Timer
var timer_label: Label
var info_label: Label
var results_label: Label
var solo_color_index := 0
var p1_color_index := 0
var p2_color_index := 1
var network_manager: NetworkManager
var online_lobby_code := ""
var online_lobby_host := false
var online_local_slot := 0
var online_player_selected_color_index := 0
var online_lobby_ui_ready := false

func _ready():
	randomize()
	world_root = Node2D.new()
	world_root.name = "World"
	add_child(world_root)
	
	ui_root = CanvasLayer.new()
	ui_root.name = "UI"
	add_child(ui_root)
	
	network_manager = NetworkManager.new()
	add_child(network_manager)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	show_main_menu()

func _process(_delta):
	if round_active:
		elapsed_time += _delta
		update_timer_label()
		check_for_game_over()
	
	if not round_active and match_started:
		if Input.is_key_pressed(KEY_R):
			start_match()
		if Input.is_key_pressed(KEY_M):
			show_main_menu()
	
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()

func clear_world():
	for child in world_root.get_children():
		child.queue_free()
	players.clear()
	bombs.clear()

func clear_ui():
	for child in ui_root.get_children():
		child.queue_free()

func make_menu_button(text_value: String, size: Vector2 = Vector2(260, 56), text_size: int = 22) -> Button:
	var btn = Button.new()
	btn.text = text_value
	btn.custom_minimum_size = size
	btn.add_theme_font_size_override("font_size", text_size)
	
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.18, 0.25, 0.95)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.85, 0.9, 1.0, 0.9)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal", normal)
	
	var hover = normal.duplicate()
	hover.bg_color = Color(0.23, 0.31, 0.43, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	
	var pressed = normal.duplicate()
	pressed.bg_color = Color(0.3, 0.43, 0.66, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)
	
	return btn

func show_main_menu():
	match_started = false
	round_active = false
	game_mode = GameMode.SOLO
	clear_ui()
	clear_world()
	
	var menu_panel = PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(900, 500)
	menu_panel.position = Vector2(190, 110)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.22, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.72, 0.8, 0.96, 1.0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	menu_panel.add_theme_stylebox_override("panel", style)
	ui_root.add_child(menu_panel)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "BOMB DODGE"
	title.add_theme_font_size_override("font_size", 54)
	title.modulate = Color(1, 1, 1, 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Choose a mode"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.modulate = Color(0.8, 0.85, 1.0, 1.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)
	
	var buttons = VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(buttons)
	
	var solo_button = make_menu_button("Solo", Vector2(260, 58), 24)
	solo_button.pressed.connect(func(): show_color_selection(GameMode.SOLO))
	buttons.add_child(solo_button)
	
	var duo_button = make_menu_button("Local Duo", Vector2(260, 58), 24)
	duo_button.pressed.connect(func(): show_color_selection(GameMode.LOCAL_MULTIPLAYER))
	buttons.add_child(duo_button)
	
	var online_button = make_menu_button("Online Multiplayer", Vector2(260, 58), 24)
	online_button.pressed.connect(func(): show_online_mode_menu())
	buttons.add_child(online_button)
	
	var quit_button = make_menu_button("Quit", Vector2(260, 58), 24)
	quit_button.pressed.connect(func(): get_tree().quit())
	buttons.add_child(quit_button)

func show_online_mode_menu():
	clear_ui()
	var panel = PanelContainer.new(); panel.custom_minimum_size = Vector2(900, 500); panel.position = Vector2(190, 110)
	var style = StyleBoxFlat.new(); style.bg_color = Color(0.12, 0.15, 0.22, 0.96); style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2; style.border_color = Color(0.72, 0.8, 0.96, 1.0); style.corner_radius_top_left = 12; style.corner_radius_top_right = 12; style.corner_radius_bottom_left = 12; style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	ui_root.add_child(panel)
	var vbox = VBoxContainer.new(); vbox.alignment = BoxContainer.ALIGNMENT_CENTER; panel.add_child(vbox)
	var title = Label.new(); title.text = "Online Multiplayer"; title.add_theme_font_size_override("font_size", 42); title.modulate = Color(1,1,1,1); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(title)
	var host_button = make_menu_button("Host Game", Vector2(260, 60), 24); host_button.pressed.connect(func(): start_online_host()); vbox.add_child(host_button)
	var join_button = make_menu_button("Join Game", Vector2(260, 60), 24); join_button.pressed.connect(func(): show_online_join_menu()); vbox.add_child(join_button)
	var back_button = make_menu_button("Back", Vector2(260, 60), 24); back_button.pressed.connect(func(): show_main_menu()); vbox.add_child(back_button)
	var note = Label.new(); note.text = "Requires a public relay server for internet play across separate PCs."; note.add_theme_font_size_override("font_size", 16); note.modulate = Color(0.82, 0.88, 1.0, 1.0); note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(note)

func show_online_join_menu():
	clear_ui()
	var panel = PanelContainer.new(); panel.custom_minimum_size = Vector2(900, 500); panel.position = Vector2(190, 110)
	var style = StyleBoxFlat.new(); style.bg_color = Color(0.12, 0.15, 0.22, 0.96); style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2; style.border_color = Color(0.72, 0.8, 0.96, 1.0); style.corner_radius_top_left = 12; style.corner_radius_top_right = 12; style.corner_radius_bottom_left = 12; style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	ui_root.add_child(panel)
	var vbox = VBoxContainer.new(); vbox.alignment = BoxContainer.ALIGNMENT_CENTER; panel.add_child(vbox)
	var title = Label.new(); title.text = "Join Online Game"; title.add_theme_font_size_override("font_size", 42); title.modulate = Color(1,1,1,1); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vbox.add_child(title)
	var ip_label = Label.new(); ip_label.text = "Server IP or hostname"; ip_label.add_theme_font_size_override("font_size", 18); vbox.add_child(ip_label)
	var ip_input = LineEdit.new(); ip_input.text = DEFAULT_SERVER_IP; ip_input.custom_minimum_size = Vector2(420, 36); vbox.add_child(ip_input)
	var code_label = Label.new(); code_label.text = "Room Code"; code_label.add_theme_font_size_override("font_size", 18); vbox.add_child(code_label)
	var code_input = LineEdit.new(); code_input.text = ""; code_input.max_length = 8; code_input.custom_minimum_size = Vector2(260, 36); vbox.add_child(code_input)
	var join_button = make_menu_button("Join Match", Vector2(260, 60), 24); join_button.pressed.connect(func():
		var code = code_input.text.strip_edges().to_upper()
		var ip = ip_input.text.strip_edges()
		if code == "":
			return
		join_online_game(ip, code)
	); vbox.add_child(join_button)
	var back_button = make_menu_button("Back", Vector2(260, 60), 24); back_button.pressed.connect(func(): show_online_mode_menu()); vbox.add_child(back_button)

func start_online_host() -> void:
	online_lobby_code = generate_room_code()
	online_lobby_host = true
	online_local_slot = 0
	online_player_selected_color_index = 0
	network_manager.room_code = online_lobby_code
	network_manager.is_host = true
	network_manager.online_players.clear()
	network_manager.online_players.append({"slot": 0, "name": "Player 1", "color_index": online_player_selected_color_index})
	network_manager.local_slot = 0
	var err = network_manager.host_game(online_lobby_code)
	if err != OK:
		print("Failed to host online game: ", err)
		show_online_mode_menu()
		return
	game_mode = GameMode.ONLINE_MULTIPLAYER
	show_online_lobby()

func join_online_game(ip: String, room_code: String) -> void:
	online_lobby_code = room_code.to_upper()
	online_lobby_host = false
	online_local_slot = 0
	online_player_selected_color_index = 0
	network_manager.room_code = online_lobby_code
	network_manager.is_host = false
	network_manager.online_players.clear()
	network_manager.online_players.append({"slot": 0, "name": "Player 1", "color_index": online_player_selected_color_index})
	network_manager.local_slot = 0
	var err = network_manager.join_game(ip, online_lobby_code)
	if err != OK:
		print("Failed to join online game: ", err)
		show_online_mode_menu()
		return
	game_mode = GameMode.ONLINE_MULTIPLAYER
	show_online_lobby()

func generate_room_code() -> String:
	var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var out = ""
	for i in range(6):
		out += letters[randi() % letters.length()]
	return out

func show_online_lobby():
	clear_ui()
	var panel = PanelContainer.new(); panel.custom_minimum_size = Vector2(980, 620); panel.position = Vector2(150, 60)
	var style = StyleBoxFlat.new(); style.bg_color = Color(0.12, 0.15, 0.22, 0.96); style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2; style.border_color = Color(0.72, 0.8, 0.96, 1.0); style.corner_radius_top_left = 12; style.corner_radius_top_right = 12; style.corner_radius_bottom_left = 12; style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	ui_root.add_child(panel)
	var root_vbox = VBoxContainer.new(); root_vbox.alignment = BoxContainer.ALIGNMENT_CENTER; root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL; panel.add_child(root_vbox)
	var title = Label.new(); title.text = "Online Lobby - Room %s" % online_lobby_code; title.add_theme_font_size_override("font_size", 34); title.modulate = Color(1,1,1,1); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root_vbox.add_child(title)
	var entry_container = GridContainer.new(); entry_container.columns = 2; entry_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL; root_vbox.add_child(entry_container)
	for i in range(ONLINE_PLAYER_LIMIT):
		var entry = PanelContainer.new(); entry.custom_minimum_size = Vector2(430, 110)
		var entry_style = StyleBoxFlat.new(); entry_style.bg_color = Color(0.17, 0.2, 0.28, 0.9); entry_style.border_width_left = 1; entry_style.border_width_top = 1; entry_style.border_width_right = 1; entry_style.border_width_bottom = 1; entry_style.border_color = Color(0.7, 0.8, 0.95, 1.0); entry_style.corner_radius_top_left = 8; entry_style.corner_radius_top_right = 8; entry_style.corner_radius_bottom_left = 8; entry_style.corner_radius_bottom_right = 8; entry.add_theme_stylebox_override("panel", entry_style)
		var entry_vbox = VBoxContainer.new(); entry_vbox.alignment = BoxContainer.ALIGNMENT_CENTER; entry.add_child(entry_vbox)
		var label = Label.new(); label.name = "Slot%sLabel" % i; label.text = "Player %d" % (i + 1); label.add_theme_font_size_override("font_size", 22); label.modulate = Color(1,1,1,1); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; entry_vbox.add_child(label)
		var slot_name = Label.new(); slot_name.name = "Slot%sName" % i; slot_name.text = "Waiting for player"; slot_name.add_theme_font_size_override("font_size", 17); slot_name.modulate = Color(0.8, 0.85, 1.0, 1.0); slot_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; entry_vbox.add_child(slot_name)
		var color_preview = ColorRect.new(); color_preview.name = "Slot%sPreview" % i; color_preview.custom_minimum_size = Vector2(80, 28); color_preview.color = Color(0.45, 0.5, 0.6, 1.0); entry_vbox.add_child(color_preview)
		if i == online_local_slot:
			var color_row = HBoxContainer.new(); color_row.alignment = BoxContainer.ALIGNMENT_CENTER; entry_vbox.add_child(color_row)
			for color_index in range(COLOR_OPTIONS.size()):
				var color_button = make_menu_button(COLOR_OPTIONS[color_index]["name"], Vector2(72, 30), 11)
				color_button.modulate = COLOR_OPTIONS[color_index]["color"]
				var pick = color_index
				color_button.pressed.connect(func():
					_online_set_local_color(pick)
				)
				color_row.add_child(color_button)
		entry_container.add_child(entry)
	_update_online_lobby_ui()
	var controls = HBoxContainer.new(); controls.alignment = BoxContainer.ALIGNMENT_CENTER; root_vbox.add_child(controls)
	var start_button = make_menu_button("Start Match", Vector2(220, 56), 22); start_button.pressed.connect(func(): start_online_match()); controls.add_child(start_button)
	var back_button = make_menu_button("Back", Vector2(220, 56), 22); back_button.pressed.connect(func(): show_online_mode_menu()); controls.add_child(back_button)
	var note = Label.new(); note.text = "Set a public server IP/host to connect from separate PCs over the internet."; note.add_theme_font_size_override("font_size", 16); note.modulate = Color(0.82, 0.88, 1.0, 1.0); note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root_vbox.add_child(note)

func _online_set_local_color(index: int) -> void:
	online_player_selected_color_index = index
	network_manager.local_color_index = index
	if network_manager.online_players.is_empty():
		network_manager.online_players.append({"slot": 0, "name": "Player 1", "color_index": index})
	else:
		if network_manager.online_players.size() > online_local_slot:
			network_manager.online_players[online_local_slot] = {"slot": online_local_slot, "name": "Player %d" % (online_local_slot + 1), "color_index": index}
	_update_online_lobby_ui()

func _update_online_lobby_ui() -> void:
	if not is_instance_valid(ui_root):
		return
	for slot_index in range(ONLINE_PLAYER_LIMIT):
		var slot_name = ui_root.find_child("Slot%sName" % slot_index, true, false)
		var slot_preview = ui_root.find_child("Slot%sPreview" % slot_index, true, false)
		if slot_name == null or slot_preview == null:
			continue
		if network_manager.online_players.size() > slot_index:
			var slot_data = network_manager.online_players[slot_index]
			slot_name.text = String(slot_data.get("name", "Player %d" % (slot_index + 1)))
			slot_preview.color = COLOR_OPTIONS[int(slot_data.get("color_index", 0))]["color"]
		else:
			slot_name.text = "Waiting for player"
			slot_preview.color = Color(0.45, 0.5, 0.6, 1.0)

func start_online_match():
	if game_mode != GameMode.ONLINE_MULTIPLAYER:
		return
	clear_ui()
	clear_world()
	match_started = true
	round_active = true
	elapsed_time = 0.0
	create_arena()
	create_match_ui()
	spawn_players()
	start_bomb_spawner()
	info_label.text = "Online match | WASD + Left Shift | 4 player max"

func show_color_selection(mode: int):
	game_mode = mode
	clear_ui()
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 500)
	panel.position = Vector2(190, 110)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.22, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.72, 0.81, 0.96, 1.0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	ui_root.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Choose your colors"
	title.add_theme_font_size_override("font_size", 36)
	title.modulate = Color(1, 1, 1, 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	if game_mode == GameMode.SOLO:
		var preview = ColorRect.new()
		preview.custom_minimum_size = Vector2(120, 120)
		preview.color = COLOR_OPTIONS[solo_color_index]["color"]
		vbox.add_child(preview)
		
		var row = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(row)
		for i in range(COLOR_OPTIONS.size()):
			var btn = make_menu_button(COLOR_OPTIONS[i]["name"], Vector2(100, 40), 16)
			btn.modulate = COLOR_OPTIONS[i]["color"]
			var pick_index = i
			btn.pressed.connect(func():
				solo_color_index = pick_index
				preview.color = COLOR_OPTIONS[pick_index]["color"]
			)
			row.add_child(btn)
		
		var start_button = make_menu_button("Start Match", Vector2(220, 56), 22)
		start_button.pressed.connect(func(): start_match())
		vbox.add_child(start_button)
	else:
		var p1_preview = ColorRect.new()
		var p2_preview = ColorRect.new()
		p1_preview.custom_minimum_size = Vector2(110, 110)
		p2_preview.custom_minimum_size = Vector2(110, 110)
		p1_preview.color = COLOR_OPTIONS[p1_color_index]["color"]
		p2_preview.color = COLOR_OPTIONS[p2_color_index]["color"]
		
		var row = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(row)
		
		var p1_box = VBoxContainer.new(); p1_box.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_child(p1_box)
		var p1_label = Label.new(); p1_label.text = "Player 1"; p1_label.add_theme_font_size_override("font_size", 22); p1_box.add_child(p1_label)
		p1_box.add_child(p1_preview)
		var p1_row = HBoxContainer.new(); p1_row.alignment = BoxContainer.ALIGNMENT_CENTER; p1_box.add_child(p1_row)
		for i in range(COLOR_OPTIONS.size()):
			var btn = make_menu_button(COLOR_OPTIONS[i]["name"], Vector2(90, 38), 15)
			btn.modulate = COLOR_OPTIONS[i]["color"]
			var pick_index = i
			btn.pressed.connect(func():
				p1_color_index = pick_index
				p1_preview.color = COLOR_OPTIONS[p1_color_index]["color"]
				if p1_color_index == p2_color_index:
					var alt = get_next_available_color_index([p1_color_index])
					if alt != -1:
						p2_color_index = alt
						p2_preview.color = COLOR_OPTIONS[p2_color_index]["color"]
			)
			p1_row.add_child(btn)
		
		var p2_box = VBoxContainer.new(); p2_box.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_child(p2_box)
		var p2_label = Label.new(); p2_label.text = "Player 2"; p2_label.add_theme_font_size_override("font_size", 22); p2_box.add_child(p2_label)
		p2_box.add_child(p2_preview)
		var p2_row = HBoxContainer.new(); p2_row.alignment = BoxContainer.ALIGNMENT_CENTER; p2_box.add_child(p2_row)
		for i in range(COLOR_OPTIONS.size()):
			var btn = make_menu_button(COLOR_OPTIONS[i]["name"], Vector2(90, 38), 15)
			btn.modulate = COLOR_OPTIONS[i]["color"]
			var pick_index = i
			btn.pressed.connect(func():
				if pick_index == p1_color_index:
					var alt = get_next_available_color_index([p1_color_index])
					if alt == -1:
						return
					p2_color_index = alt
				else:
					p2_color_index = pick_index
				p2_preview.color = COLOR_OPTIONS[p2_color_index]["color"]
			)
			p2_row.add_child(btn)
		
		var start_button = make_menu_button("Start Match", Vector2(220, 56), 22)
		start_button.pressed.connect(func(): start_match())
		vbox.add_child(start_button)
	
	var back_button = make_menu_button("Back to Menu", Vector2(220, 56), 22)
	back_button.pressed.connect(func(): show_main_menu())
	vbox.add_child(back_button)

func get_next_available_color_index(excluded_indices: Array) -> int:
	for i in range(COLOR_OPTIONS.size()):
		if not excluded_indices.has(i):
			return i
	return -1

func create_arena():
	var bg = ColorRect.new(); bg.position = Vector2.ZERO; bg.size = Vector2(ARENA_WIDTH, ARENA_HEIGHT); bg.color = Color(0.02, 0.08, 0.18, 1.0); world_root.add_child(bg)
	var floor = ColorRect.new(); floor.position = Vector2(50, 50); floor.size = Vector2(ARENA_WIDTH - 100, ARENA_HEIGHT - 100); floor.color = Color(0.94, 0.94, 0.9, 1.0); world_root.add_child(floor)
	var border_color = Color(0.42, 0.55, 0.72, 1.0)
	var border_thickness = 4
	var border_nodes = [
		[Vector2(0, 0), Vector2(ARENA_WIDTH, border_thickness)],
		[Vector2(0, ARENA_HEIGHT - border_thickness), Vector2(ARENA_WIDTH, border_thickness)],
		[Vector2(0, 0), Vector2(border_thickness, ARENA_HEIGHT)],
		[Vector2(ARENA_WIDTH - border_thickness, 0), Vector2(border_thickness, ARENA_HEIGHT)],
	]
	for data in border_nodes:
		var border = ColorRect.new(); border.position = data[0]; border.size = data[1]; border.color = border_color; world_root.add_child(border)
	
	var wall_thickness = 30
	var walls = [
		[Vector2(0, ARENA_HEIGHT / 2), Vector2(wall_thickness, ARENA_HEIGHT)],
		[Vector2(ARENA_WIDTH - wall_thickness, ARENA_HEIGHT / 2), Vector2(wall_thickness, ARENA_HEIGHT)],
		[Vector2(ARENA_WIDTH / 2, 0), Vector2(ARENA_WIDTH, wall_thickness)],
		[Vector2(ARENA_WIDTH / 2, ARENA_HEIGHT - wall_thickness), Vector2(ARENA_WIDTH, wall_thickness)],
	]
	for wall_data in walls:
		var wall = StaticBody2D.new(); var shape = CollisionShape2D.new(); var rect = RectangleShape2D.new(); rect.extents = wall_data[1] / 2; shape.shape = rect; wall.add_child(shape); wall.position = wall_data[0]; world_root.add_child(wall)
	
	var deco_color = Color(0.76, 0.79, 0.82, 1.0)
	for i in range(4):
		var deco = ColorRect.new(); deco.position = Vector2(110 + (i * 260), 130 + (i % 2) * 240); deco.size = Vector2(74, 74); deco.color = deco_color; world_root.add_child(deco)

func create_match_ui():
	if timer_label != null:
		timer_label.queue_free()
	if info_label != null:
		info_label.queue_free()
	if results_label != null:
		results_label.queue_free()
	
	timer_label = Label.new(); timer_label.text = "Time: 0.0s"; timer_label.position = Vector2(420, 18); timer_label.add_theme_font_size_override("font_size", 36); timer_label.modulate = Color(1,1,1,1); timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; timer_label.custom_minimum_size = Vector2(440,40); ui_root.add_child(timer_label)
	info_label = Label.new(); info_label.text = ""; info_label.position = Vector2(380, 655); info_label.add_theme_font_size_override("font_size", 18); info_label.modulate = Color(0.82, 0.88, 1.0, 1.0); info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; info_label.custom_minimum_size = Vector2(520,30); ui_root.add_child(info_label)
	results_label = Label.new(); results_label.text = ""; results_label.position = Vector2(220, 150); results_label.custom_minimum_size = Vector2(840,400); results_label.add_theme_font_size_override("font_size", 30); results_label.modulate = Color(1,1,1,1); results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; results_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; results_label.visible = false; ui_root.add_child(results_label)
	update_timer_label()

func update_timer_label():
	if timer_label != null:
		timer_label.text = "Time: %.1fs" % elapsed_time

func start_match():
	clear_ui()
	clear_world()
	match_started = true
	round_active = true
	elapsed_time = 0.0
	create_arena()
	create_match_ui()
	spawn_players()
	start_bomb_spawner()
	
	if game_mode == GameMode.SOLO:
		info_label.text = "WASD to move - survive as long as you can"
	elif game_mode == GameMode.LOCAL_MULTIPLAYER:
		info_label.text = "Player 1: WASD | Player 2: Arrow Keys"
	else:
		info_label.text = "Online match | WASD + Left Shift | 4 player max"

func spawn_players():
	players.clear()
	if game_mode == GameMode.SOLO:
		var player = PLAYER_SCENE.instantiate(); player.name = "Player1"; player.position = Vector2(200, ARENA_HEIGHT / 2); player.set_player_name("Player"); player.set_player_id(1); player.set_player_color(COLOR_OPTIONS[solo_color_index]["color"]); world_root.add_child(player); players.append(player); return
	if game_mode == GameMode.LOCAL_MULTIPLAYER:
		var player1 = PLAYER_SCENE.instantiate(); player1.name = "Player1"; player1.position = Vector2(200, ARENA_HEIGHT / 2); player1.set_player_name("Player 1"); player1.set_player_id(1); player1.set_player_color(COLOR_OPTIONS[p1_color_index]["color"]); world_root.add_child(player1); players.append(player1)
		var player2 = PLAYER_SCENE.instantiate(); player2.name = "Player2"; player2.position = Vector2(1080, ARENA_HEIGHT / 2); player2.set_player_name("Player 2"); player2.set_player_id(2); player2.set_player_color(COLOR_OPTIONS[p2_color_index]["color"]); world_root.add_child(player2); players.append(player2); return
	
	var ordered_players = network_manager.online_players
	for i in range(min(ordered_players.size(), ONLINE_PLAYER_LIMIT)):
		var slot_data = ordered_players[i]
		var player = PLAYER_SCENE.instantiate()
		var x_pos = 200.0 + (i % 2) * 760.0
		var y_pos = 200.0 + (i / 2) * 220.0
		player.name = "OnlinePlayer_%d" % (i + 1)
		player.position = Vector2(x_pos, y_pos)
		player.set_player_name(String(slot_data.get("name", "Player %d" % (i + 1))))
		player.set_player_id(i + 1)
		player.set_player_color(COLOR_OPTIONS[int(slot_data.get("color_index", 0))]["color"])
		player.set_network_player(true)
		if i == network_manager.local_slot:
			player.set_online_local_controller(true)
		world_root.add_child(player)
		players.append(player)

func start_bomb_spawner():
	if bomb_timer != null:
		bomb_timer.stop(); bomb_timer.queue_free()
	bomb_timer = Timer.new(); bomb_timer.wait_time = 0.22; bomb_timer.autostart = true; bomb_timer.one_shot = false; bomb_timer.timeout.connect(_spawn_bomb); world_root.add_child(bomb_timer)
	for i in range(randi_range(MIN_ACTIVE_BOMBS, MAX_ACTIVE_BOMBS)):
		_spawn_single_bomb()

func _spawn_single_bomb():
	if bombs.size() >= MAX_ACTIVE_BOMBS:
		return
	var safe_pos = find_valid_bomb_position()
	if safe_pos == null:
		return
	var bomb = BOMB_SCENE.instantiate(); bomb.name = "Bomb"; bomb.position = safe_pos; world_root.add_child(bomb); bombs.append(bomb)
	bomb.tree_exiting.connect(func():
		if bombs.has(bomb): bombs.erase(bomb)
	)

func _spawn_bomb():
	if not round_active:
		return
	if bombs.size() < MIN_ACTIVE_BOMBS:
		_spawn_single_bomb(); return
	if bombs.size() < MAX_ACTIVE_BOMBS and randf() < 0.9:
		_spawn_single_bomb()

func find_valid_bomb_position() -> Vector2:
	for i in range(90):
		var x = randf_range(90, ARENA_WIDTH - 90)
		var y = randf_range(90, ARENA_HEIGHT - 90)
		var pos = Vector2(x, y)
		var valid = true
		for player in players:
			if player != null and player.is_inside_tree():
				if player.global_position.distance_to(pos) < 140:
					valid = false; break
		if valid:
			for bomb in bombs:
				if bomb != null and bomb.is_inside_tree():
					if bomb.global_position.distance_to(pos) < 90:
						valid = false; break
		if valid:
			return pos
	return Vector2.ZERO

func check_for_game_over():
	var alive_players = []
	for player in get_tree().get_nodes_in_group("players"):
		if player.alive:
			alive_players.append(player)
	if game_mode == GameMode.SOLO:
		if alive_players.size() == 0:
			round_active = false
			if bomb_timer != null: bomb_timer.stop()
			show_results(alive_players)
		return
	if game_mode == GameMode.LOCAL_MULTIPLAYER:
		if alive_players.size() <= 1:
			round_active = false
			if bomb_timer != null: bomb_timer.stop()
			show_results(alive_players)
		return
	if game_mode == GameMode.ONLINE_MULTIPLAYER:
		if alive_players.size() <= 1:
			round_active = false
			if bomb_timer != null: bomb_timer.stop()
			show_results(alive_players)
		return

func show_results(alive_players: Array):
	var result_text = ""
	if game_mode == GameMode.SOLO:
		if alive_players.size() == 1:
			result_text = "YOU SURVIVED\n%.1fs\n\nPress R to retry\nM for menu" % elapsed_time
		else:
			result_text = "YOU WERE HIT!\nFinal Time: %.1fs\n\nPress R to retry\nM for menu" % elapsed_time
	elif game_mode == GameMode.LOCAL_MULTIPLAYER:
		if alive_players.size() == 1:
			var winner = alive_players[0]
			if winner.player_id == 1:
				result_text = "PLAYER 1 WINS!\n%.1fs\n\nPress R to retry\nM for menu" % elapsed_time
			else:
				result_text = "PLAYER 2 WINS!\n%.1fs\n\nPress R to retry\nM for menu" % elapsed_time
		else:
			result_text = "DRAW!\nBoth players were eliminated\n\nPress R to retry\nM for menu"
	else:
		if alive_players.size() == 1:
			var winner = alive_players[0]
			result_text = "PLAYER %d WINS!\n%.1fs\n\nPress R to retry\nM for menu" % [winner.player_id, elapsed_time]
		else:
			result_text = "ONLINE DRAW!\nAll players eliminated\n\nPress R to retry\nM for menu"
	results_label.text = result_text
	results_label.visible = true
	results_label.modulate = Color(1, 1, 1, 1)

func _on_peer_connected(id):
	print("Peer connected: ", id)

func _on_peer_disconnected(id):
	print("Peer disconnected: ", id)

func _on_connected_to_server():
	print("Connected to server.")

func _on_connection_failed():
	print("Connection to server failed.")
	show_online_mode_menu()

