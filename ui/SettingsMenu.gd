extends Control

@onready var mic_option: OptionButton = %MicOptionButton
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var resume_button: Button = %ResumeButton
@onready var disconnect_button: Button = %DisconnectButton

func _ready() -> void:
	# 1. Populate Microphone List and Slider
	_refresh_mic_list()
	sensitivity_slider.value = VoiceManager.voice_threshold
	
	# 2. Connect Signals
	mic_option.item_selected.connect(_on_mic_selected)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	resume_button.pressed.connect(_on_resume_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	
	# Initial focus for controller support (optional)
	resume_button.grab_focus()

func _refresh_mic_list() -> void:
	mic_option.clear()
	var devices = AudioServer.get_input_device_list()
	var current_device = AudioServer.input_device
	
	var current_idx = 0
	for i in range(devices.size()):
		var device_name = devices[i]
		mic_option.add_item(device_name)
		if device_name == current_device:
			current_idx = i
			
	mic_option.selected = current_idx

func _on_mic_selected(index: int) -> void:
	var device_name = mic_option.get_item_text(index)
	AudioServer.input_device = device_name
	print("[Settings] Microphone set to: ", device_name)

func _on_sensitivity_changed(value: float) -> void:
	VoiceManager.voice_threshold = value

func _on_disconnect_pressed() -> void:
	print("[Settings] Disconnecting from server...")
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	
	# Transition back to main menu
	SceneManager._load_scene(SceneManager.MENU_SCENE)
	queue_free()

func _on_resume_pressed() -> void:
	# Close the menu
	queue_free()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
