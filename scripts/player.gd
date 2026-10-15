extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died

@export var speed: float = 220.0
@export var max_health: int = 100

var health: int
var is_dead: bool = false

func _ready() -> void:
	add_to_group("player")
	health = max_health
	health_changed.emit(health, max_health)

func _physics_process(_delta: float) -> void:
	if is_dead:
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

func take_damage(amount: int) -> void:
	if is_dead:
		return

	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)

	if health == 0:
		is_dead = true
		died.emit()
