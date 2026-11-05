extends Decal

func _ready() -> void:
	# Fade out over time
	var tween = create_tween()
	tween.tween_interval(5.0) # Stay for 5 seconds
	tween.tween_property(self, "modulate:a", 0.0, 2.0) # Fade alpha to 0 over 2 seconds
	tween.tween_callback(queue_free)
