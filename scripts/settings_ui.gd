extends CanvasLayer

@onready var panel: PanelContainer = $SettingsPanel
@onready var btn_gear: Button = $GearButton

@onready var btn_close: Button = $SettingsPanel/MarginContainer/VBoxContainer/Header/BtnClose
@onready var opt_quality: OptionButton = $SettingsPanel/MarginContainer/VBoxContainer/QualityContainer/QualityOption

@onready var sld_music: HSlider = $SettingsPanel/MarginContainer/VBoxContainer/MusicContainer/MusicSlider
@onready var chk_music: CheckBox = $SettingsPanel/MarginContainer/VBoxContainer/MusicContainer/MusicMute

@onready var sld_sfx: HSlider = $SettingsPanel/MarginContainer/VBoxContainer/SFXContainer/SFXSlider
@onready var chk_sfx: CheckBox = $SettingsPanel/MarginContainer/VBoxContainer/SFXContainer/SFXMute

func _ready() -> void:
	panel.hide()
	
	btn_gear.pressed.connect(_on_gear_pressed)
	btn_close.pressed.connect(_on_close_pressed)
	
	opt_quality.item_selected.connect(_on_quality_selected)
	
	sld_music.value_changed.connect(_on_music_value_changed)
	chk_music.toggled.connect(_on_music_mute_toggled)
	
	sld_sfx.value_changed.connect(_on_sfx_value_changed)
	chk_sfx.toggled.connect(_on_sfx_mute_toggled)
	
	# Delay initial UI sync by 1 frame to ensure SettingsManager has loaded
	call_deferred("_update_ui_from_settings")

func _update_ui_from_settings() -> void:
	opt_quality.set_block_signals(true)
	sld_music.set_block_signals(true)
	chk_music.set_block_signals(true)
	sld_sfx.set_block_signals(true)
	chk_sfx.set_block_signals(true)
	
	opt_quality.selected = SettingsManager.quality_level
	sld_music.value = SettingsManager.music_volume
	chk_music.button_pressed = SettingsManager.music_muted
	sld_sfx.value = SettingsManager.sfx_volume
	chk_sfx.button_pressed = SettingsManager.sfx_muted
	
	opt_quality.set_block_signals(false)
	sld_music.set_block_signals(false)
	chk_music.set_block_signals(false)
	sld_sfx.set_block_signals(false)
	chk_sfx.set_block_signals(false)

func _on_gear_pressed() -> void:
	panel.show()
	_update_ui_from_settings()

func _on_close_pressed() -> void:
	panel.hide()

func _on_quality_selected(index: int) -> void:
	SettingsManager.set_quality_level(index)

func _on_music_value_changed(value: float) -> void:
	SettingsManager.set_music_volume(value)

func _on_music_mute_toggled(button_pressed: bool) -> void:
	SettingsManager.set_music_muted(button_pressed)

func _on_sfx_value_changed(value: float) -> void:
	SettingsManager.set_sfx_volume(value)

func _on_sfx_mute_toggled(button_pressed: bool) -> void:
	SettingsManager.set_sfx_muted(button_pressed)
