extends Node2D

const ARENA_SIZE := Vector2(1152, 648)
const CANDLE_POS := Vector2(576, 324)
const PLAYER_SPEED := 260.0
const CANDLE_MAX := 100.0
const DAWN_TIME := 90.0

@onready var stats_label: Label = $HUD/Stats
@onready var state_label: Label = $HUD/State

var player_pos := CANDLE_POS + Vector2(0, 120)
var candle_power := CANDLE_MAX
var time_survived := 0.0
var spawn_timer := 0.0
var spawn_interval := 2.0
var wax_timer := 0.0
var game_over := false
var won := false

var enemies: Array[Dictionary] = []
var wax_drops: Array[Vector2] = []

func _ready() -> void:
	set_process(true)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if game_over:
		if Input.is_key_pressed(KEY_R):
			reset_game()
		queue_redraw()
		return

	time_survived += delta
	candle_power = max(candle_power - (2.4 * delta), 0.0)

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1

	if input_dir != Vector2.ZERO:
		player_pos += input_dir.normalized() * PLAYER_SPEED * delta
		player_pos.x = clamp(player_pos.x, 24.0, ARENA_SIZE.x - 24.0)
		player_pos.y = clamp(player_pos.y, 24.0, ARENA_SIZE.y - 24.0)

	if Input.is_key_pressed(KEY_SPACE) and candle_power > 8.0:
		candle_power = max(candle_power - (16.0 * delta), 0.0)
		repel_enemies(delta)

	spawn_timer += delta
	wax_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		spawn_enemy()
		spawn_interval = max(0.55, spawn_interval - 0.02)

	if wax_timer >= 5.0 and wax_drops.size() < 3:
		wax_timer = 0.0
		spawn_wax_drop()

	update_enemies(delta)
	collect_wax()

	if candle_power <= 0.0:
		game_over = true
		won = false
	elif time_survived >= DAWN_TIME:
		game_over = true
		won = true

	update_hud()
	queue_redraw()


func repel_enemies(delta: float) -> void:
	for enemy in enemies:
		var offset: Vector2 = enemy["pos"] - player_pos
		var distance := max(offset.length(), 0.001)
		if distance < 150.0:
			enemy["pos"] += offset.normalized() * (230.0 * delta)


func update_enemies(delta: float) -> void:
	var survivors: Array[Dictionary] = []
	for enemy in enemies:
		var enemy_pos: Vector2 = enemy["pos"]
		var target := CANDLE_POS
		if player_pos.distance_to(enemy_pos) < 110.0:
			target = player_pos

		enemy_pos += (target - enemy_pos).normalized() * enemy["speed"] * delta
		enemy["pos"] = enemy_pos

		var near_player := enemy_pos.distance_to(player_pos) < 20.0
		if near_player:
			candle_power = max(candle_power - (enemy["damage"] * 0.45 * delta), 0.0)

		var near_candle := enemy_pos.distance_to(CANDLE_POS) < 32.0
		if near_candle:
			candle_power = max(candle_power - (enemy["damage"] * delta), 0.0)
			continue

		survivors.append(enemy)
	enemies = survivors


func collect_wax() -> void:
	var left: Array[Vector2] = []
	for drop in wax_drops:
		if player_pos.distance_to(drop) < 26.0:
			candle_power = min(candle_power + 19.0, CANDLE_MAX)
		else:
			left.append(drop)
	wax_drops = left


func spawn_enemy() -> void:
	var edge := randi() % 4
	var pos := Vector2.ZERO
	if edge == 0:
		pos = Vector2(randf() * ARENA_SIZE.x, -20)
	elif edge == 1:
		pos = Vector2(ARENA_SIZE.x + 20, randf() * ARENA_SIZE.y)
	elif edge == 2:
		pos = Vector2(randf() * ARENA_SIZE.x, ARENA_SIZE.y + 20)
	else:
		pos = Vector2(-20, randf() * ARENA_SIZE.y)

	enemies.append({
		"pos": pos,
		"speed": randf_range(72.0, 122.0),
		"damage": randf_range(7.0, 12.0)
	})


func spawn_wax_drop() -> void:
	wax_drops.append(Vector2(
		randf_range(80.0, ARENA_SIZE.x - 80.0),
		randf_range(80.0, ARENA_SIZE.y - 80.0)
	))


func update_hud() -> void:
	var dawn_left := max(DAWN_TIME - time_survived, 0.0)
	stats_label.text = "Candle: %.0f%%   Dawn in: %.0fs   Shadows: %d" % [candle_power, dawn_left, enemies.size()]
	if game_over:
		state_label.text = "Dawn breaks! You kept hope alive. Press R to restart." if won else "The last candle has gone out... Press R to try again."
	else:
		state_label.text = "Move: WASD/Arrows   Hold Space: repel shadows (uses candle power)"


func reset_game() -> void:
	player_pos = CANDLE_POS + Vector2(0, 120)
	candle_power = CANDLE_MAX
	time_survived = 0.0
	spawn_timer = 0.0
	wax_timer = 0.0
	spawn_interval = 2.0
	enemies.clear()
	wax_drops.clear()
	game_over = false
	won = false
	update_hud()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color(0.04, 0.04, 0.08))

	var light_radius := lerpf(110.0, 260.0, candle_power / CANDLE_MAX)
	draw_circle(CANDLE_POS, light_radius, Color(1.0, 0.78, 0.35, 0.1))
	draw_circle(CANDLE_POS, 14.0, Color(1.0, 0.92, 0.6))
	draw_circle(CANDLE_POS, 5.0, Color(1.0, 0.55, 0.2))

	for drop in wax_drops:
		draw_circle(drop, 10.0, Color(1.0, 0.95, 0.5))

	for enemy in enemies:
		draw_circle(enemy["pos"], 11.0, Color(0.5, 0.1, 0.1))

	draw_circle(player_pos, 13.0, Color(0.7, 0.9, 1.0))
	if not game_over and Input.is_key_pressed(KEY_SPACE):
		draw_circle(player_pos, 150.0, Color(1.0, 0.6, 0.2, 0.08))
