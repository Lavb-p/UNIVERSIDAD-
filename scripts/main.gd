extends Node2D

var crystals_collected: int = 0
var total_crystals: int = 0

## Margen que se le suma a las paredes al generar la malla de navegación.
## Debe ser >= a la mitad del tamaño del guardia (su cápsula mide ~29 x 44 px
## en pantalla) para que la ruta no roce esquinas ni paredes.
@export var navigation_agent_radius: float = 24.0

@onready var crystal_label: Label = \
	$UI/HUD/CrystalLabel

@onready var ground: TileMapLayer = $ground
@onready var walls: TileMapLayer = $walls
@onready var navigation_region: NavigationRegion2D = $NavigationRegion2D

func _ready() -> void:
	var crystals := $crystals.get_children()

	total_crystals = crystals.size()

	for crystal in crystals:
		crystal.collected.connect(
			_on_crystal_collected
		)

	update_crystal_label()

	setup_navigation()

func _on_crystal_collected() -> void:
	crystals_collected += 1
	update_crystal_label()

	if crystals_collected >= total_crystals:
		print("¡Todos los cristales recolectados!")

func update_crystal_label() -> void:
	crystal_label.text = "Cristales: %d / %d" % [
		crystals_collected,
		total_crystals
	]

## Genera la malla de navegación que usan los NavigationAgent2D de los guardias.
## - Contorno exterior: el área que cubren los TileMapLayer del mapa.
## - Obstáculos: los StaticBody2D / CollisionShape2D de las paredes (walls.tscn),
##   así la ruta siempre es coherente con las colisiones reales.
func setup_navigation() -> void:
	var navigation_polygon := NavigationPolygon.new()
	navigation_polygon.agent_radius = navigation_agent_radius

	var tile_size := Vector2(ground.tile_set.tile_size)
	var used_rect: Rect2i = ground.get_used_rect().merge(
		walls.get_used_rect()
	)

	var top_left: Vector2 = Vector2(used_rect.position) * tile_size
	var bottom_right: Vector2 = Vector2(used_rect.end) * tile_size

	navigation_polygon.add_outline(PackedVector2Array([
		top_left,
		Vector2(bottom_right.x, top_left.y),
		bottom_right,
		Vector2(top_left.x, bottom_right.y)
	]))

	var source_geometry := NavigationMeshSourceGeometryData2D.new()

	NavigationServer2D.parse_source_geometry_data(
		navigation_polygon,
		source_geometry,
		self
	)

	NavigationServer2D.bake_from_source_geometry_data(
		navigation_polygon,
		source_geometry
	)

	navigation_region.navigation_polygon = navigation_polygon
