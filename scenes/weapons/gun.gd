extends Node3D

@onready var muzzle_flash: Node3D = $MuzzleFlash
@onready var barrel_smoke: GPUParticles3D = $BarrelSmoke

func shoot() -> void:
	if muzzle_flash:
		muzzle_flash.flash()
	if barrel_smoke:
		barrel_smoke.restart()
