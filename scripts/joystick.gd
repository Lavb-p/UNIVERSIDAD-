extends Control
## Controles táctiles: joystick de movimiento + botones de ataque e interacción.
##
## No mueve al jugador directamente: envía las mismas acciones que el teclado
## (move_left / move_right / move_up / move_down / player_attack / interact),
## así player.gd, npc.gd y dialog_box.gd funcionan igual con teclado y con táctil.

## Si es false, los controles solo aparecen en dispositivos con pantalla táctil.
@export var show_on_desktop: bool = true
## Distancia máxima (px) que puede moverse el botón central del joystick.
@export var max_distance: float = 70.0
## Por debajo de este valor (0 a 1) el joystick se considera en reposo.
@export var stick_deadzone: float = 0.2

const ATTACK_COLOR := Color(0.85, 0.15, 0.15)
const INTERACT_COLOR := Color(0.2, 0.6, 0.95)

@onready var stick: Control = $Stick
@onready var attack_button: Control = $AttackButton
@onready var interact_button: Control = $InteractButton

# Índice del dedo que controla cada elemento (-1 = ninguno).
var _stick_touch: int = -1
var _attack_touch: int = -1
var _interact_touch: int = -1

var _knob_offset: Vector2 = Vector2.ZERO
var _stick_vector: Vector2 = Vector2.ZERO

# Última fuerza enviada por acción, para no repetir eventos iguales.
var _sent_strength: Dictionary = {}


func _ready() -> void:
	visible = show_on_desktop or DisplayServer.is_touchscreen_available()

	stick.draw.connect(_draw_stick)

	attack_button.draw.connect(func() -> void:
		_draw_button(attack_button, "ATACAR", ATTACK_COLOR, _attack_touch != -1)
	)

	interact_button.draw.connect(func() -> void:
		_draw_button(interact_button, "ACCIÓN", INTERACT_COLOR, _interact_touch != -1)
	)


# ---------------------------------------------------------------------------
# Entrada táctil
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_on_touch_pressed(event.index, event.position)
		else:
			_on_touch_released(event.index)

	elif event is InputEventScreenDrag:
		if event.index == _stick_touch:
			_update_stick(event.position)


func _on_touch_pressed(index: int, touch_position: Vector2) -> void:
	if _stick_touch == -1 and stick.get_global_rect().grow(30.0).has_point(touch_position):
		_stick_touch = index
		_update_stick(touch_position)

	elif _attack_touch == -1 and attack_button.get_global_rect().has_point(touch_position):
		_attack_touch = index
		_send_action("player_attack", 1.0)
		attack_button.queue_redraw()

	elif _interact_touch == -1 and interact_button.get_global_rect().has_point(touch_position):
		_interact_touch = index
		_send_action("interact", 1.0)
		interact_button.queue_redraw()


func _on_touch_released(index: int) -> void:
	if index == _stick_touch:
		_stick_touch = -1
		_knob_offset = Vector2.ZERO
		_stick_vector = Vector2.ZERO
		_apply_movement()
		stick.queue_redraw()

	elif index == _attack_touch:
		_attack_touch = -1
		_send_action("player_attack", 0.0)
		attack_button.queue_redraw()

	elif index == _interact_touch:
		_interact_touch = -1
		_send_action("interact", 0.0)
		interact_button.queue_redraw()


# ---------------------------------------------------------------------------
# Movimiento
# ---------------------------------------------------------------------------

func _update_stick(touch_position: Vector2) -> void:
	var center: Vector2 = stick.get_global_rect().get_center()
	var offset: Vector2 = touch_position - center

	if offset.length() > max_distance:
		offset = offset.normalized() * max_distance

	_knob_offset = offset
	_stick_vector = offset / max_distance

	_apply_movement()
	stick.queue_redraw()


func _apply_movement() -> void:
	var direction: Vector2 = _stick_vector

	if direction.length() < stick_deadzone:
		direction = Vector2.ZERO

	_send_action("move_right", maxf(direction.x, 0.0))
	_send_action("move_left", maxf(-direction.x, 0.0))
	_send_action("move_down", maxf(direction.y, 0.0))
	_send_action("move_up", maxf(-direction.y, 0.0))


## Envía una acción como si se hubiera pulsado una tecla (strength 0 = soltar).
func _send_action(action: StringName, strength: float) -> void:
	if is_equal_approx(float(_sent_strength.get(action, 0.0)), strength):
		return

	_sent_strength[action] = strength

	var event := InputEventAction.new()
	event.action = action
	event.pressed = strength > 0.0
	event.strength = strength

	Input.parse_input_event(event)


func _release_all() -> void:
	_stick_touch = -1
	_attack_touch = -1
	_interact_touch = -1
	_knob_offset = Vector2.ZERO
	_stick_vector = Vector2.ZERO

	for action in ["move_left", "move_right", "move_up", "move_down", "player_attack", "interact"]:
		_send_action(action, 0.0)

	if is_inside_tree():
		stick.queue_redraw()
		attack_button.queue_redraw()
		interact_button.queue_redraw()


func _notification(what: int) -> void:
	# Si la app pierde el foco con un dedo apoyado, se sueltan todos los controles.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PREDELETE:
		_release_all()


# ---------------------------------------------------------------------------
# Dibujo (no se necesitan imágenes)
# ---------------------------------------------------------------------------

func _draw_stick() -> void:
	var center: Vector2 = stick.size / 2.0
	var radius: float = stick.size.x / 2.0

	stick.draw_circle(center, radius, Color(0.05, 0.05, 0.12, 0.45))
	stick.draw_arc(center, radius - 2.0, 0.0, TAU, 48, Color(1, 1, 1, 0.6), 3.0, true)

	var knob_center: Vector2 = center + _knob_offset
	var knob_alpha: float = 0.35 if _stick_touch == -1 else 0.7

	stick.draw_circle(knob_center, 34.0, Color(1, 1, 1, knob_alpha))
	stick.draw_arc(knob_center, 34.0, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 3.0, true)


func _draw_button(button: Control, label: String, color: Color, is_pressed: bool) -> void:
	var center: Vector2 = button.size / 2.0
	var radius: float = button.size.x / 2.0

	var fill: Color = color
	fill.a = 0.85 if is_pressed else 0.5

	button.draw_circle(center, radius, fill)
	button.draw_arc(center, radius - 2.0, 0.0, TAU, 48, Color(1, 1, 1, 0.85), 3.0, true)

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 18
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline_y: float = center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0

	button.draw_string(
		font,
		Vector2(center.x - text_size.x / 2.0, baseline_y),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.WHITE
	)
