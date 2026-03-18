extends Node3D

@export var flash_time: float = 0.05

@onready var light: OmniLight3D = $OmniLight3D
@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	# Hide by default
	hide()

func flash() -> void:
	show()
	# Randomize rotation for variety
	mesh.rotation.z = randf_range(0, TAU)
	
	# Start a timer to hide it
	await get_tree().create_timer(flash_time).timeout
	hide()
