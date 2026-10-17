class_name SeaImpactBurst
extends DestructionBurst
## Existing CPU spray/mist pool plus a short expanding surface foam ring.
var foam: MeshInstance3D
var foam_material: StandardMaterial3D
func _ready() -> void:
	water_impact=true
	duration=3.3
	super._ready()
	for i in range(particles.size()):
		velocities[i]=Vector3(rng.randf_range(-6,6),rng.randf_range(7,18),rng.randf_range(-6,6))*strength
		lifetimes[i]=rng.randf_range(.6,1.3) if i<12 else rng.randf_range(1.8,3.0)
	foam_material=MeshKit.material(Color(.8,.9,.9,.55))
	foam_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring:=TorusMesh.new()
	ring.inner_radius=1.0
	ring.outer_radius=1.4
	ring.rings=32
	ring.ring_segments=8
	foam=MeshKit.mesh(self,ring,foam_material,Vector3.UP*.04)
	foam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var progress:=clampf(elapsed/3.1,0,1)
	foam.scale=Vector3(1+progress*7*strength,.1,1+progress*7*strength)
	foam_material.albedo_color.a=(1-progress)*.6
