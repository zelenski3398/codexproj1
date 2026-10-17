extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):
		await physics_frame
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS: " if ok else "FAIL: ", description)
func run() -> void:
	var game: Node3D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_flight("spitfire")
	game.enemy.ai.combat_enabled = false
	game.aircraft.pilot.automated = true
	await frames(4)
	var display: AircraftDamageHUD = game.hud.damage_display
	check(display.labels.size() == 12 and display.diagram.SHAPES.size() == 12, "All twelve components have a diagram segment and numeric readout")
	check(display.mouse_filter == Control.MOUSE_FILTER_IGNORE and display.diagram.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Damage display leaves flight mouse input untouched")
	for id in AircraftDamage.IDS:
		check(display.ratios[id] == 1 and display.labels[id].text.ends_with("100%"), String(id) + " starts at full independent component health")
		var definition: AircraftComponentDefinition = game.aircraft.components.definitions[id]
		game.aircraft.components.apply_damage(id, definition.max_integrity * 0.2 / definition.damage_multiplier)
		display.refresh(game.aircraft.components)
		check(is_equal_approx(display.ratios[id], 0.8) and is_equal_approx(display.bars[id].value, 0.8), String(id) + " reflects actual profile-scaled damage")
		game.aircraft.request_reset()
		await frames(3)
	check(AircraftDamageHUD.health_color(1).is_equal_approx(AircraftDamageHUD.HEALTHY), "Healthy component is green")
	check(AircraftDamageHUD.health_color(0.5).is_equal_approx(AircraftDamageHUD.WARNING), "Half-health component is amber")
	check(AircraftDamageHUD.health_color(0).is_equal_approx(AircraftDamageHUD.CRITICAL), "Failed component is red")
	check(not AircraftDamageHUD.health_color(0.9).is_equal_approx(AircraftDamageHUD.health_color(0.8)), "Colour interpolates continuously with damage severity")
	check(display.ratios.values().all(func(v):return v == 1), "Existing reset restores green full-health readouts")
	var rect: Rect2 = display.get_global_rect()
	check(rect.end.y <= display.get_viewport_rect().size.y and rect.position.y > display.get_viewport_rect().size.y * 0.7, "Panel fits at the bottom of the viewport")
	check(game.hud.speed_label.get_global_rect().end.y < rect.position.y, "Existing flight instruments stay clear of component display")
	game.show_selection()
	await frames(3)
	game.start_flight("sea_gladiator")
	await frames(3)
	check(game.hud.damage_display.ratios.size() == 12 and game.hud.damage_display.ratios.values().all(func(v):return v == 1), "Aircraft switching binds the Gladiator's own component health")
	game.queue_free()
	await frames(3)
	print("AIRCRAFT DAMAGE HUD RESULT: ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)
