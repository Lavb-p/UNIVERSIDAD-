extends CharacterBody2D

enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	RETURN
}


@export var patrol_speed: float = 70.0
@export var chase_speed: float = 115.0
@export var arrival_distance: float = 12.0

@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0

@export var idle_duration: float = 1.0
@export var repath_distance: float = 8.0

## Vida del guardia. Cada golpe del jugador quita 10.
@export var max_health: int = 30

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

@onready var patrol_a: Marker2D = $PositionPatrolA
@onready var patrol_b: Marker2D = $PositionPatrolB

var state: State = State.IDLE
var player: CharacterBody2D = null

var home_position: Vector2
var patrol_positions: Array[Vector2] = []
var patrol_index: int = 0

var idle_timer: float = 0.0
var attack_timer: float = 0.0

var facing_direction: String = "down"
var navigation_ready: bool = false

var health: int = 0
var is_dead: bool = false


func _ready() -> void:
	# El jugador busca a los guardias por este grupo al atacar.
	add_to_group("guards")
	health = max_health

	home_position = global_position

	# Guardamos las posiciones globales de patrullaje.
	# Así no se mueven junto con el guardia.
	patrol_positions = [
		patrol_a.global_position,
		patrol_b.global_position
	]

	# Juego top-down: sin gravedad ni "suelo". En modo FLOATING el guardia
	# se desliza por las paredes y no se traba en las esquinas de la ruta.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	# Configuración de navegación.
	navigation_agent.path_desired_distance = 8.0
	navigation_agent.target_desired_distance = 10.0
	navigation_agent.avoidance_enabled = false

	# Las señales body_entered / body_exited de DetectionArea ya están
	# conectadas desde guard.tscn. Si también se conectan por código, Godot
	# muestra el error de "conexión duplicada".

	# Estado inicial.
	state = State.IDLE
	idle_timer = idle_duration

	# Esperar a que el mapa de navegación esté listo.
	call_deferred("_initialize_navigation")


func _initialize_navigation() -> void:
	var map: RID = navigation_agent.get_navigation_map()

	# main.gd genera la malla (NavigationRegion2D) en su _ready() y el
	# servidor de navegación la sincroniza en los siguientes frames de física.
	# Hasta entonces no puede calcular ninguna ruta.
	var frames_waited: int = 0

	while NavigationServer2D.map_get_path(
		map,
		global_position,
		patrol_positions[0],
		true
	).is_empty():
		await get_tree().physics_frame

		if not is_inside_tree():
			return

		frames_waited += 1

		if frames_waited == 180:
			push_warning(
				"Guardia sin malla de navegación: revisa el NavigationRegion2D de main."
			)

	# Si un punto quedó dentro de una pared (o muy pegado a ella), se mueve
	# al punto navegable más cercano para que el guardia siempre pueda llegar.
	for i in patrol_positions.size():
		patrol_positions[i] = NavigationServer2D.map_get_closest_point(
			map,
			patrol_positions[i]
		)

	home_position = NavigationServer2D.map_get_closest_point(
		map,
		home_position
	)

	navigation_ready = true

	navigation_agent.target_position = home_position


func _physics_process(delta: float) -> void:
	if not navigation_ready:
		velocity = Vector2.ZERO
		return

	attack_timer = maxf(attack_timer - delta, 0.0)

	match state:
		State.IDLE:
			process_idle(delta)

		State.PATROL:
			process_patrol()

		State.CHASE:
			process_chase()

		State.ATTACK:
			process_attack()

		State.RETURN:
			process_return()

	move_and_slide()
	update_animation()


func take_damage(amount: int) -> void:
	if is_dead:
		return

	health = maxi(health - amount, 0)
	print("Guardia recibió daño. Vida: ", health)

	if health == 0:
		die()
		return

	sprite.modulate = Color(1.0, 0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)


func die() -> void:
	is_dead = true
	player = null
	velocity = Vector2.ZERO

	# Deja de pensar, de detectar y de bloquear el paso.
	set_physics_process(false)
	detection_area.set_deferred("monitoring", false)
	attack_area.set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)

	print("Guardia derrotado")

	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(queue_free)


func process_idle(delta: float) -> void:
	velocity = Vector2.ZERO

	idle_timer -= delta

	if idle_timer <= 0.0:
		change_state(State.PATROL)


func process_patrol() -> void:
	if patrol_positions.is_empty():
		velocity = Vector2.ZERO
		return

	var target: Vector2 = patrol_positions[patrol_index]

	navigate_to(target, patrol_speed)

	if global_position.distance_to(target) <= arrival_distance:
		velocity = Vector2.ZERO

		patrol_index = (
			patrol_index + 1
		) % patrol_positions.size()

		change_state(State.IDLE)


func process_chase() -> void:
	# Si el jugador murió o ya no existe, se deja de perseguir.
	if not is_player_alive():
		lose_player()
		return

	if is_player_in_attack_range():
		velocity = Vector2.ZERO
		change_state(State.ATTACK)
		return

	navigate_to(
		player.global_position,
		chase_speed
	)


func process_attack() -> void:
	velocity = Vector2.ZERO

	# Si el jugador perdió el 100% de su vida (o ya no existe),
	# el guardia deja de atacar de inmediato.
	if not is_player_alive():
		lose_player()
		return

	if not is_player_in_attack_range():
		change_state(State.CHASE)
		return

	# Orientarse hacia el jugador.
	var direction: Vector2 = (
		player.global_position - global_position
	)

	update_facing_direction(direction)

	if attack_timer <= 0.0:
		attack_player()


func attack_player() -> void:
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

	attack_timer = attack_cooldown

	print(
		"Guardia atacó al jugador. Vida restante: ",
		player.get("health")
	)

	# Si este golpe dejó al jugador sin vida, no se vuelve a atacar.
	if not is_player_alive():
		lose_player()


func process_return() -> void:
	navigate_to(
		home_position,
		patrol_speed
	)

	if global_position.distance_to(home_position) <= arrival_distance:
		velocity = Vector2.ZERO
		change_state(State.IDLE)


func navigate_to(
	target: Vector2,
	movement_speed: float
) -> void:

	if not navigation_ready:
		velocity = Vector2.ZERO
		return

	# Solo actualizar destino si ha cambiado.
	if navigation_agent.target_position.distance_to(target) > repath_distance:
		navigation_agent.target_position = target

	# Comprobar si terminó el recorrido.
	if navigation_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return

	# Obtener el siguiente punto de la ruta.
	var next_position: Vector2 = (
		navigation_agent.get_next_path_position()
	)

	# Calcular dirección hacia ese punto.
	var direction: Vector2 = (
		global_position.direction_to(next_position)
	)

	velocity = direction * movement_speed


func _on_detection_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if not body is CharacterBody2D:
		return

	# Un jugador sin vida ya no es un objetivo.
	if bool(body.get("is_dead")):
		return

	player = body as CharacterBody2D
	change_state(State.CHASE)


func _on_detection_body_exited(body: Node2D) -> void:
	if body == player:
		lose_player()


func is_player_alive() -> bool:
	if not is_instance_valid(player):
		return false

	return not bool(player.get("is_dead"))


## El guardia olvida al jugador y regresa a su posición de origen.
func lose_player() -> void:
	player = null
	velocity = Vector2.ZERO
	change_state(State.RETURN)


func is_player_in_attack_range() -> bool:
	if not is_instance_valid(player):
		return false

	return attack_area.overlaps_body(player)


func change_state(new_state: State) -> void:
	if state == new_state:
		return

	state = new_state

	match state:
		State.IDLE:
			idle_timer = idle_duration
			velocity = Vector2.ZERO

		State.PATROL:
			pass

		State.CHASE:
			pass

		State.ATTACK:
			velocity = Vector2.ZERO

		State.RETURN:
			pass

	print("Estado del guardia: ", State.keys()[state])


func update_animation() -> void:
	if velocity.length() > 5.0:
		update_facing_direction(velocity)

	var prefix: String = "idle"

	if velocity.length() > 5.0:
		prefix = "walk"

	var animation_name: String = (
		prefix + "_" + facing_direction
	)

	if sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation(animation_name):
		if sprite.animation != animation_name or not sprite.is_playing():
			sprite.play(animation_name)


func update_facing_direction(direction: Vector2) -> void:
	if direction.length_squared() < 0.001:
		return

	if absf(direction.x) > absf(direction.y):
		if direction.x > 0.0:
			facing_direction = "right"
		else:
			facing_direction = "left"
	else:
		if direction.y > 0.0:
			facing_direction = "down"
		else:
			facing_direction = "up"
