extends CanvasLayer

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var color_rect: ColorRect = %ColorRect
@onready var vbox: VBoxContainer = %VBoxContainer
@onready var status_label: Label = %StatusLabel

var current_status: String = ""

func _ready() -> void:
	# Start invisible for transition
	color_rect.modulate.a = 0
	vbox.modulate.a = 0
	
	if progress_bar:
		progress_bar.indeterminate = true
		progress_bar.show_percentage = false
	
	if status_label and current_status != "":
		status_label.text = current_status
	# Fade in
	var tween = create_tween().set_parallel(true)
	tween.tween_property(color_rect, "modulate:a", 1.0, 0.3)
	tween.tween_property(vbox, "modulate:a", 1.0, 0.3)

func set_status(text: String) -> void:
	current_status = text
	if status_label:
		status_label.text = text
		print("[LoadingScreen] Status updated: ", text)

func fade_out() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(color_rect, "modulate:a", 0.0, 0.5)
	tween.tween_property(vbox, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(queue_free)
