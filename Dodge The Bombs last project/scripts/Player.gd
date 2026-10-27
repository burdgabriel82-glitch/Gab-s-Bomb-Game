extends CharacterBody2D

const SPEED = 450.0
const DASH_SPEED = 900.0
const DASH_TIME = 0.18
const DASH_COOLDOWN = 5.0

var alive = true
var player_name := "Player"
var player_id := 1
var player_color := Color(0, 0.8, 1, 1)
var dash_timer := 0.0
var dash_cooldown := 0.0
var last_movement_direction := Vector2.RIGHT
var network_player := false
var local_online_controller := false

func _ready():
	add_to_group("players")
	if has_node("ColorRect"):
		$ColorRect.color = player_color

func _physics_process(delta):
	if not alive:
		return
	if dash_timer > 0.0:
		dash_timer -= delta
	else:
		dash_timer = 0.0
	if dash_cooldown > 0.0:
		dash_cooldown -= delta
	else:
		dash_cooldown = 0.0
	if network_player:
		_handle_online_input(delta)
		return
	_handle_local_input()

func _handle_local_input():
	var move = Vector2.ZERO
	if player_id == 1:
		if Input.is_key_pressed(KEY_W):
			move.y -= 1
		if Input.is_key_pressed(KEY_S):
			move.y += 1
		if Input.is_key_pressed(KEY_A):
			move.x -= 1
		if Input.is_key_pressed(KEY_D):
			move.x += 1
		if Input.is_key_pressed(KEY_SHIFT) and dash_cooldown <= 0.0:
			dash_timer = DASH_TIME
			dash_cooldown = DASH_COOLDOWN
	else:
		if Input.is_key_pressed(KEY_UP):
			move.y -= 1
		if Input.is_key_pressed(KEY_DOWN):
			move.y += 1
		if Input.is_key_pressed(KEY_LEFT):
			move.x -= 1
		if Input.is_key_pressed(KEY_RIGHT):
			move.x += 1
		if Input.is_key_pressed(KEY_SPACE) and dash_cooldown <= 0.0:
			dash_timer = DASH_TIME
			dash_cooldown = DASH_COOLDOWN
	
	if move.length() > 0.0:
		move = move.normalized()
		last_movement_direction = move
	var current_speed = SPEED
	if dash_timer > 0.0:
		current_speed = DASH_SPEED
	velocity = move * current_speed
	move_and_slide()

func _handle_online_input(_delta):
	if not local_online_controller:
		return
	var move = Vector2.ZERO
	if Input.is_key_pressed(KEY_W): move.y -= 1
	if Input.is_key_pressed(KEY_S): move.y += 1
	if Input.is_key_pressed(KEY_A): move.x -= 1
	if Input.is_key_pressed(KEY_D): move.x += 1
	if move.length() > 0.0:
		move = move.normalized()
		last_movement_direction = move
	if Input.is_key_pressed(KEY_SHIFT) and dash_cooldown <= 0.0:
		if move.length() == 0.0:
			move = last_movement_direction
		dash_timer = DASH_TIME
		dash_cooldown = DASH_COOLDOWN
	var current_speed = SPEED
	if dash_timer > 0.0:
		current_speed = DASH_SPEED
	velocity = move * current_speed
	move_and_slide()

func set_player_name(name_text: String):
	player_name = name_text

func get_player_name() -> String:
	return player_name

func set_player_id(id: int):
	player_id = id

func set_player_color(color: Color):
	player_color = color
	if has_node("ColorRect"):
		$ColorRect.color = player_color

func set_network_player(enabled: bool):
	network_player = enabled

func set_online_local_controller(enabled: bool):
	local_online_controller = enabled

func die():
	alive = false
	visible = false
	set_physics_process(false)

