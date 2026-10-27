extends Area2D

var countdown := randf_range(3.0, 5.0)
var explosion_radius := 120.0
var exploded := false

@onready var label: Label = $Label

func _ready():
	label.text = str(int(ceil(countdown)))
	label.modulate = Color(1, 1, 1, 1)
	label.add_theme_font_size_override("font_size", 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _process(delta):
	if exploded:
		return
	countdown -= delta
	label.text = str(max(0, ceil(countdown)))
	if countdown <= 0:
		explode()

func _draw():
	if exploded:
		draw_circle(Vector2.ZERO, explosion_radius, Color(1.0, 0.35, 0.12, 0.18))
		draw_circle(Vector2.ZERO, explosion_radius * 0.7, Color(1.0, 0.6, 0.2, 0.26))
		return
	
	draw_circle(Vector2.ZERO, 20.0, Color(1.0, 0.72, 0.2, 1.0))
	draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.95, 0.8, 1.0))
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 16, Color(1.0, 0.50, 0.1, 0.5), 3.0)

func explode():
	exploded = true
	label.visible = false
	monitoring = false
	
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if player.alive and player.global_position.distance_to(global_position) <= explosion_radius:
			player.die()
	
	queue_redraw()
	await get_tree().create_timer(0.15).timeout
	queue_free()
