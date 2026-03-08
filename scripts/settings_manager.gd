extends Node

const SETTINGS_FILE_PATH = "user://settings.cfg"

var music_volume: float = 1.0 # 0.0 to 1.0
var sfx_volume: float = 1.0   # 0.0 to 1.0
var music_muted: bool = false
var sfx_muted: bool = false
var quality_level: int = 2 # 0: Low, 1: Medium, 2: High

func _ready() -> void:
	load_settings()
	apply_all_settings()

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE_PATH)
	if err != OK:
		return # Use defaults
	
	music_volume = config.get_value("Audio", "music_volume", 1.0)
	sfx_volume = config.get_value("Audio", "sfx_volume", 1.0)
	music_muted = config.get_value("Audio", "music_muted", false)
	sfx_muted = config.get_value("Audio", "sfx_muted", false)
	quality_level = config.get_value("Video", "quality_level", 2)

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("Audio", "music_volume", music_volume)
	config.set_value("Audio", "sfx_volume", sfx_volume)
	config.set_value("Audio", "music_muted", music_muted)
	config.set_value("Audio", "sfx_muted", sfx_muted)
	config.set_value("Video", "quality_level", quality_level)
	config.save(SETTINGS_FILE_PATH)

func apply_all_settings() -> void:
	apply_audio_settings()
	apply_video_settings()

func apply_audio_settings() -> void:
	var music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index != -1:
		AudioServer.set_bus_mute(music_bus_index, music_muted)
		AudioServer.set_bus_volume_db(music_bus_index, linear_to_db(max(music_volume, 0.001)))

	var sfx_bus_index = AudioServer.get_bus_index("SFX")
	if sfx_bus_index != -1:
		AudioServer.set_bus_mute(sfx_bus_index, sfx_muted)
		AudioServer.set_bus_volume_db(sfx_bus_index, linear_to_db(max(sfx_volume, 0.001)))

func apply_video_settings() -> void:
	match quality_level:
		0: # Low
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			get_viewport().msaa_2d = Viewport.MSAA_DISABLED
		1: # Medium
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			get_viewport().msaa_2d = Viewport.MSAA_2X
		2: # High
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			get_viewport().msaa_2d = Viewport.MSAA_4X

func set_music_volume(v: float) -> void:
	music_volume = v
	apply_audio_settings()
	save_settings()

func set_sfx_volume(v: float) -> void:
	sfx_volume = v
	apply_audio_settings()
	save_settings()

func set_music_muted(m: bool) -> void:
	music_muted = m
	apply_audio_settings()
	save_settings()

func set_sfx_muted(m: bool) -> void:
	sfx_muted = m
	apply_audio_settings()
	save_settings()

func set_quality_level(q: int) -> void:
	quality_level = q
	apply_video_settings()
	save_settings()
