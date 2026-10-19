extends RefCounted
## T-083 native-scale sprite preview only; rescue animation belongs to T-084.


static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.set_paused(true)
	var origin: Vector2i = state.map.command_center_origin()
	var cc_centre: Vector2 = Vector2(origin + Vector2i.ONE) * Grid.TILE
	var helicopter_position: Vector2 = cc_centre + Vector2(208, 0)
	var world: Node2D = main.get_node("World") as Node2D
	var body: Sprite2D = Sprite2D.new()
	body.name = "HelicopterAssetPreview"
	body.texture = load("res://assets/fx/helicopter_body.png") as Texture2D
	body.position = helicopter_position
	body.z_index = 4
	world.add_child(body)
	var rotor: Sprite2D = Sprite2D.new()
	rotor.name = "Rotor"
	rotor.texture = load("res://assets/fx/helicopter_rotor.png") as Texture2D
	rotor.rotation = deg_to_rad(20.0)
	body.add_child(rotor)
	# Display the existing radio sprite as a static comparison; no victory state.
	var radio: Sprite2D = Sprite2D.new()
	radio.name = "RadioAssetComparison"
	radio.texture = load("res://assets/buildings/radio_tower.png") as Texture2D
	radio.position = cc_centre + Vector2(-192, 0)
	world.add_child(radio)
	var camera: CameraController = main.get_node("World/Camera2D") as CameraController
	camera.zoom = Vector2.ONE
	camera.position = helicopter_position
	camera.set_process(false)
