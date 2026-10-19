extends Control

## Se emite al abrirse un diálogo (para congelar al jugador).
signal dialog_started
## Se emite al terminar la última línea de un diálogo.
signal dialog_finished

@export var characters_per_second: float = 45.0

@onready var name_label: Label = $Panel/NameLabel
@onready var text_label: Label = $Panel/TextLabel

var is_dialog_active: bool = false

var _lines: Array = []
var _line_index: int = 0
var _typing_tween: Tween = null
var _message_id: int = 0


func _ready() -> void:
	hide()


# ---------------------------------------------------------------------------
# Diálogo con varias líneas (se avanza con "interact")
# ---------------------------------------------------------------------------

func show_dialog(lines: Array, speaker: String = "") -> void:
	if lines.is_empty():
		return

	_message_id += 1  # cancela cualquier mensaje temporal pendiente

	_lines = lines
	_line_index = 0
	is_dialog_active = true

	_set_speaker(speaker)
	show()
	_show_current_line()

	dialog_started.emit()


func advance() -> void:
	# Si el texto aún se está escribiendo, primero se completa la línea.
	if text_label.visible_ratio < 1.0:
		_finish_typing()
		return

	_line_index += 1

	if _line_index >= _lines.size():
		close_dialog()
	else:
		_show_current_line()


func close_dialog() -> void:
	if not is_dialog_active:
		return

	is_dialog_active = false
	_kill_typing()
	hide()
	dialog_finished.emit()


# ---------------------------------------------------------------------------
# Mensaje corto que se cierra solo (avisos del juego)
# ---------------------------------------------------------------------------

func show_message(text: String, duration: float = 2.5, speaker: String = "") -> void:
	# Un diálogo en curso tiene prioridad sobre los avisos.
	if is_dialog_active:
		return

	_message_id += 1
	var current_id: int = _message_id

	_set_speaker(speaker)
	show()
	_type_text(text)

	await get_tree().create_timer(duration).timeout

	# Solo se oculta si no apareció otro mensaje o diálogo mientras tanto.
	if current_id == _message_id and not is_dialog_active:
		hide()


func hide_message() -> void:
	if is_dialog_active:
		return

	_message_id += 1
	_kill_typing()
	hide()


# ---------------------------------------------------------------------------
# Entrada
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if is_dialog_active and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		advance()


# ---------------------------------------------------------------------------
# Auxiliares
# ---------------------------------------------------------------------------

func _set_speaker(speaker: String) -> void:
	name_label.text = speaker
	name_label.visible = speaker != ""


func _show_current_line() -> void:
	_type_text(str(_lines[_line_index]))


## Efecto de máquina de escribir.
func _type_text(text: String) -> void:
	_kill_typing()

	text_label.text = text
	text_label.visible_ratio = 0.0

	var duration: float = maxf(text.length() / characters_per_second, 0.05)

	_typing_tween = create_tween()
	_typing_tween.tween_property(text_label, "visible_ratio", 1.0, duration)


func _finish_typing() -> void:
	_kill_typing()
	text_label.visible_ratio = 1.0


func _kill_typing() -> void:
	if _typing_tween != null and _typing_tween.is_valid():
		_typing_tween.kill()

	_typing_tween = null
