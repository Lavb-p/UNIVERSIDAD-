extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died

@export var speed: float = 220.0
@export var max_health: int = 100

@export var attack_damage: int = 10
## Alcance del ataque en píxeles (alrededor del jugador).
@export var attack_range: float = 56.0
@export var attack_cooldown: float = 0.4

var health: int
var is_dead: bool = false

## main.gd lo desactiva mientras hay un diálogo abierto.
var input_enabled: bool = true

var attack_timer: float = 0.0
var footstep_timer: float = 0.0
var _attack_fx: float = -1.0  # progreso del efecto visual (0 a 1), -1 = oculto

func _ready() -> void:
	add_to_group("player")
	health = max_health
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	attack_timer = maxf(attack_timer - delta, 0.0)

	if is_dead or not input_enabled:
		velocity = Vector2.ZERO
		return

	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = direction * speed
	move_and_slide()
	if velocity.length() > 10.0:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			AudioManager.play_sfx("step")
			footstep_timer = 0.34
	else:
		footstep_timer = 0.0

# Llega tanto de la tecla (Espacio) como del botón ATACAR del joystick.
func _unhandled_input(event: InputEvent) -> void:
	if is_dead or not input_enabled:
		return

	if event.is_action_pressed("player_attack"):
		attack()

func attack() -> void:
	if attack_timer > 0.0:
		return

	attack_timer = attack_cooldown
	_play_attack_effect()

	# Daña a todos los guardias que estén dentro del alcance.
	for guard in get_tree().get_nodes_in_group("guards"):
		if guard.global_position.distance_to(global_position) <= attack_range:
			if guard.has_method("take_damage"):
				guard.take_damage(attack_damage)

func take_damage(amount: int) -> void:
	if is_dead:
		return

	health = maxi(health - amount, 0)
	AudioManager.play_sfx("hit")
	health_changed.emit(health, max_health)
	_flash_damage()

	if health == 0:
		is_dead = true
		AudioManager.play_sfx("death")
		died.emit()

func _flash_damage() -> void:
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	sprite.modulate = Color(1.0, 0.35, 0.35)

	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

# Anillo blanco que se expande para mostrar el alcance del golpe.
func _play_attack_effect() -> void:
	var tween := create_tween()
	tween.tween_method(_set_attack_fx, 0.0, 1.0, 0.18)
	tween.tween_callback(_set_attack_fx.bind(-1.0))

func _set_attack_fx(value: float) -> void:
	_attack_fx = value
	queue_redraw()

func _draw() -> void:
	if _attack_fx < 0.0:
		return

	var radius: float = lerpf(attack_range * 0.4, attack_range, _attack_fx)
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		48,
		Color(1.0, 1.0, 1.0, 1.0 - _attack_fx),
		4.0,
		true
	)
