extends Area2D

## El jugador está cerca y pulsó "interact" (tecla E o botón del joystick).
signal interacted

@onready var hint_label: Label = $HintLabel

var player_in_range: bool = false
var is_talking: bool = false


func _ready() -> void:
	# En pantallas táctiles no existe la tecla E.
	if DisplayServer.is_touchscreen_available():
		hint_label.text = "Interactuar"
	else:
		hint_label.text = "[E] Hablar"

	hint_label.hide()

# body_entered y body_exited están conectadas desde npc.tscn.

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_update_hint()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range or is_talking:
		return

	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interacted.emit()


## main.gd lo usa para ocultar el aviso mientras el NPC habla.
func set_talking(value: bool) -> void:
	is_talking = value
	_update_hint()


func _update_hint() -> void:
	hint_label.visible = player_in_range and not is_talking
