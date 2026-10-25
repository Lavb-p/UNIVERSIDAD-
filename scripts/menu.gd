extends Control

const GAME := "res://scenes/main.tscn"
const CRYSTAL := preload("res://assets/items/crystal.png")
var menu_box: VBoxContainer
var settings_box: VBoxContainer
var volume_label: Label

func _ready() -> void:
	_build()

func _build() -> void:
	var bg := ColorRect.new(); bg.color = Color("101329"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var glow := ColorRect.new(); glow.color = Color(0.1,0.32,0.48,0.35); glow.size = Vector2(520,520); glow.position = Vector2(70,60); glow.rotation = 0.18; add_child(glow)
	var crystal := TextureRect.new(); crystal.texture=CRYSTAL; crystal.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; crystal.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; crystal.size=Vector2(360,440); crystal.position=Vector2(90,80); crystal.modulate=Color(0.62,0.9,1,0.88); add_child(crystal)
	var shade := ColorRect.new(); shade.color=Color(0.035,0.045,0.1,0.38); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(shade)
	var layout := VBoxContainer.new(); layout.set_anchors_preset(Control.PRESET_CENTER_RIGHT); layout.position=Vector2(-430,-230); layout.size=Vector2(360,460); layout.add_theme_constant_override("separation",14); add_child(layout)
	var title := Label.new(); title.text="GUARDIANES\nDEL CRISTAL"; title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",42); title.add_theme_color_override("font_color",Color("e8f5ff")); title.add_theme_color_override("font_shadow_color",Color("2b9dbb")); title.add_theme_constant_override("shadow_offset_x",2); title.add_theme_constant_override("shadow_offset_y",3); layout.add_child(title)
	var subtitle := Label.new(); subtitle.text="Una aventura para restaurar la luz"; subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; subtitle.add_theme_font_size_override("font_size",16); subtitle.add_theme_color_override("font_color",Color("a9c9dc")); layout.add_child(subtitle)
	menu_box=VBoxContainer.new(); menu_box.add_theme_constant_override("separation",12); layout.add_child(menu_box)
	_add_button(menu_box,"PLAY",_play)
	_add_button(menu_box,"SETTINGS",_show_settings)
	var load_button := _add_button(menu_box,"CARGAR PARTIDA",_load)
	load_button.disabled=not SaveManager.has_save()
	_add_button(menu_box,"SALIR",_quit)
	settings_box=VBoxContainer.new(); settings_box.visible=false; settings_box.add_theme_constant_override("separation",12); layout.add_child(settings_box)
	var volume_title := Label.new(); volume_title.text="VOLUMEN DE SONIDO"; volume_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; volume_title.add_theme_color_override("font_color",Color("e8f5ff")); settings_box.add_child(volume_title)
	var slider := HSlider.new(); slider.min_value=0; slider.max_value=100; slider.step=1; slider.value=AudioManager.volume*100; slider.custom_minimum_size=Vector2(330,32); slider.value_changed.connect(_on_volume_changed); settings_box.add_child(slider)
	volume_label=Label.new(); volume_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; _on_volume_changed(slider.value); settings_box.add_child(volume_label)
	_add_button(settings_box,"VOLVER",_show_main)

func _add_button(parent: VBoxContainer, label: String, callback: Callable) -> Button:
	var button := Button.new(); button.text=label; button.custom_minimum_size=Vector2(330,54); button.add_theme_font_size_override("font_size",20)
	var normal := StyleBoxFlat.new(); normal.bg_color=Color("202b48"); normal.border_color=Color("5dc5d6"); normal.set_border_width_all(2); normal.set_corner_radius_all(12); normal.content_margin_top=8; normal.content_margin_bottom=8
	var hover := normal.duplicate(); hover.bg_color=Color("2a4962")
	button.add_theme_stylebox_override("normal",normal); button.add_theme_stylebox_override("hover",hover); button.add_theme_stylebox_override("pressed",hover); button.add_theme_color_override("font_color",Color("f2f7ff")); button.pressed.connect(callback); parent.add_child(button); return button

func _on_volume_changed(value: float) -> void:
	AudioManager.set_volume(value/100.0)
	if volume_label: volume_label.text="%d%%" % int(value)
func _show_settings() -> void:
	menu_box.visible=false; settings_box.visible=true
func _show_main() -> void:
	settings_box.visible=false; menu_box.visible=true
func _play() -> void:
	SaveManager.pending_save={}; get_tree().change_scene_to_file(GAME)
func _load() -> void:
	if SaveManager.request_load(): get_tree().change_scene_to_file(GAME)
func _quit() -> void:
	get_tree().quit()
