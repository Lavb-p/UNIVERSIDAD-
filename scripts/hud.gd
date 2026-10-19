extends Control

# Recortes de assets/ui/44_corazones_vida.png (corazón lleno y corazón vacío).
const HEARTS_TEXTURE: Texture2D = preload("res://assets/ui/44_corazones_vida.png")
const HEART_FULL_REGION: Rect2 = Rect2(7, 0, 31, 28)
const HEART_EMPTY_REGION: Rect2 = Rect2(138, 0, 31, 28)

## Cantidad de corazones. Cada uno vale max_health / hearts_count de vida
## (con 100 de vida: 5 corazones de 20; cada golpe de 10 quita medio corazón).
@export var hearts_count: int = 5
@export var heart_size: Vector2 = Vector2(40, 36)

@onready var hearts_row: HBoxContainer = $StatusPanel/Margin/VBox/HeartsRow
@onready var crystal_label: Label = $StatusPanel/Margin/VBox/CrystalRow/CrystalLabel
@onready var mission_label: Label = $MissionPanel/Margin/VBox/MissionLabel

# Contenedor recortable de cada corazón: su ancho define cuánto está "lleno".
var _heart_fills: Array[Control] = []


func _ready() -> void:
	_build_hearts()


func _build_hearts() -> void:
	var full_texture := AtlasTexture.new()
	full_texture.atlas = HEARTS_TEXTURE
	full_texture.region = HEART_FULL_REGION

	var empty_texture := AtlasTexture.new()
	empty_texture.atlas = HEARTS_TEXTURE
	empty_texture.region = HEART_EMPTY_REGION

	for i in hearts_count:
		var slot := Control.new()
		slot.custom_minimum_size = heart_size

		# Corazón vacío (fondo).
		var empty_heart := _make_heart_texture(empty_texture)

		# Corazón lleno dentro de un contenedor que recorta por la derecha.
		var clip := Control.new()
		clip.clip_contents = true
		clip.size = heart_size

		var full_heart := _make_heart_texture(full_texture)

		clip.add_child(full_heart)
		slot.add_child(empty_heart)
		slot.add_child(clip)
		hearts_row.add_child(slot)

		_heart_fills.append(clip)


func _make_heart_texture(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = heart_size
	return rect


# ---------------------------------------------------------------------------
# API pública (la usa main.gd)
# ---------------------------------------------------------------------------

func update_health(current: int, maximum: int) -> void:
	var health_per_heart: float = float(maximum) / float(hearts_count)

	for i in _heart_fills.size():
		var fill: float = (float(current) - i * health_per_heart) / health_per_heart
		_heart_fills[i].size.x = heart_size.x * clampf(fill, 0.0, 1.0)


func update_crystals(collected: int, total: int) -> void:
	crystal_label.text = "%d / %d" % [collected, total]


func set_mission_text(text: String, completed: bool = false) -> void:
	mission_label.text = text

	if completed:
		mission_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	else:
		mission_label.remove_theme_color_override("font_color")
