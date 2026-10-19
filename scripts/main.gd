extends Node2D

enum MissionState {
	NOT_STARTED,
	ACTIVE,
	COMPLETED
}

var mission_state: MissionState = MissionState.NOT_STARTED
var crystals_collected: int = 0
var total_crystals: int = 0

## Margen que se le suma a las paredes al generar la malla de navegación.
## Debe ser >= a la mitad del tamaño del guardia (su cápsula mide ~29 x 44 px
## en pantalla) para que la ruta no roce esquinas ni paredes.
@export var navigation_agent_radius: float = 24.0

@onready var ground: TileMapLayer = $ground
@onready var walls: TileMapLayer = $walls
@onready var navigation_region: NavigationRegion2D = $NavigationRegion2D

@onready var player = $player
@onready var npc = $NPC
@onready var hud = $UI/HUD
@onready var dialog_box = $UI/DialogBox
# La escena del joystick ($UI/Joystick) se comunica solo con acciones de Input
# (ver joystick.gd), por eso main no necesita referenciarla.


func _ready() -> void:
	var crystals := $crystals.get_children()
	total_crystals = crystals.size()

	for crystal in crystals:
		crystal.touched.connect(_on_crystal_touched)
		crystal.player_left.connect(_on_crystal_player_left)

	npc.interacted.connect(_on_npc_interacted)

	# El jugador no se mueve mientras hay un diálogo abierto.
	dialog_box.dialog_started.connect(_on_dialog_started)
	dialog_box.dialog_finished.connect(_on_dialog_finished)

	player.health_changed.connect(hud.update_health)
	player.died.connect(_on_player_died)

	# El player emite health_changed en su _ready, antes de que main se conecte,
	# por eso se muestra el valor inicial manualmente.
	hud.update_health(player.health, player.max_health)

	_update_hud()
	setup_navigation()


# ---------------------------------------------------------------------------
# Misión
# ---------------------------------------------------------------------------

func _on_npc_interacted() -> void:
	if dialog_box.is_dialog_active:
		return

	var lines: Array
	var speaker: String = "Anciano"

	match mission_state:
		MissionState.NOT_STARTED:
			lines = [
				"¡Bienvenido, guardián! El gran cristal del reino se rompió en tres fragmentos.",
				"Los fragmentos están esparcidos por el mapa. Recógelos todos, pero ten cuidado con los guardias rojos.",
				"Cuando reúnas los tres cristales, el reino volverá a estar a salvo. ¡Mucha suerte!"
			]
		MissionState.ACTIVE:
			var remaining: int = total_crystals - crystals_collected
			lines = ["Aún te faltan %d cristales. ¡Sigue buscando, guardián!" % remaining]
		_:
			lines = ["¡Lo lograste! Gracias a ti el cristal vuelve a brillar. El reino te lo agradece."]

	npc.set_talking(true)
	dialog_box.show_dialog(lines, speaker)

	await dialog_box.dialog_finished

	npc.set_talking(false)

	# La misión comienza cuando termina la primera conversación.
	if mission_state == MissionState.NOT_STARTED:
		start_mission()


func start_mission() -> void:
	mission_state = MissionState.ACTIVE
	_update_hud()

	dialog_box.show_message(
		"¡Misión iniciada! Recoge los %d cristales." % total_crystals,
		3.0,
		"Misión"
	)


func complete_mission() -> void:
	mission_state = MissionState.COMPLETED
	_update_hud()

	dialog_box.show_message(
		"¡Misión cumplida! Recuperaste todos los cristales. Vuelve con el anciano.",
		4.0,
		"Misión"
	)


func _on_crystal_touched(crystal: Area2D) -> void:
	# Los cristales solo se cuentan cuando la misión está activa.
	if mission_state != MissionState.ACTIVE:
		dialog_box.show_message(
			"Todavía no tienes una misión. Habla primero con el anciano.",
			3.0,
			"Aviso"
		)
		return

	crystal.collect()
	crystals_collected += 1
	_update_hud()

	if crystals_collected >= total_crystals:
		complete_mission()
	else:
		dialog_box.show_message(
			"¡Cristal recogido! Te faltan %d." % (total_crystals - crystals_collected),
			2.0,
			"Misión"
		)


func _on_crystal_player_left() -> void:
	# Al alejarse de un cristal bloqueado se cierra el aviso.
	dialog_box.hide_message()


func _update_hud() -> void:
	hud.update_crystals(crystals_collected, total_crystals)

	match mission_state:
		MissionState.NOT_STARTED:
			hud.set_mission_text("Habla con el anciano para recibir tu misión.")
		MissionState.ACTIVE:
			hud.set_mission_text(
				"Recoge los cristales: %d / %d" % [crystals_collected, total_crystals]
			)
		MissionState.COMPLETED:
			hud.set_mission_text("¡Misión completada!", true)


# ---------------------------------------------------------------------------
# Jugador y diálogo
# ---------------------------------------------------------------------------

func _on_dialog_started() -> void:
	player.input_enabled = false


func _on_dialog_finished() -> void:
	player.input_enabled = true


func _on_player_died() -> void:
	if dialog_box.is_dialog_active:
		dialog_box.close_dialog()

	dialog_box.show_message("¡Has sido derrotado! Reiniciando...", 2.5, "Aviso")

	await get_tree().create_timer(2.5).timeout
	get_tree().reload_current_scene()


# ---------------------------------------------------------------------------
# Navegación
# ---------------------------------------------------------------------------

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
