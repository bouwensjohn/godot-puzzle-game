extends Node2D

@export var background_texture: Texture2D
@export var scale_factor: float = 1.0

func _ready() -> void:
	set("z_index", -10)
	create_parallax_background()
	create_ice_floor()

func _draw() -> void:
	pass

func create_parallax_background() -> void:
	var pb := ParallaxBackground.new()
	pb.name = "ParallaxBackground"
	pb.layer = -1
	add_child(pb)

	var world_w := GameConfig.SCREEN_WIDTH * scale_factor
	var world_h := GameConfig.SCREEN_HEIGHT * scale_factor

	var far := ParallaxLayer.new()
	far.name = "ParallaxFar"
	far.motion_scale = Vector2(0.2, 0.2)
	pb.add_child(far)

	var far_map := TileMap.new()
	far_map.name = "ParallaxFarMap"
	far_map.set("modulate", Color(0.85, 0.9, 1.0, 0.4))
	far_map.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var far_mat := CanvasItemMaterial.new()
	far_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	far_map.material = far_mat

	var far_ts := TileSet.new()
	far_ts.tile_size = Vector2i(128, 128)
	var far_tex := load("res://textures/pushy_ice_tile_01_128_a80.png") as Texture2D
	if far_tex:
		var fatlas := TileSetAtlasSource.new()
		fatlas.texture = far_tex
		fatlas.texture_region_size = Vector2i(128, 128)
		fatlas.create_tile(Vector2i(0, 0))
		far_ts.add_source(fatlas)
	far_map.tile_set = far_ts
	far.add_child(far_map)

	var ftx := int(ceil(world_w / 128.0)) + 2
	var fty := int(ceil(world_h / 128.0)) + 2
	for y in range(-1, fty):
		for x in range(-1, ftx):
			if randf() < 0.18:
				far_map.set_cell(0, Vector2i(x, y), 0, Vector2i(0, 0), 0)

	var mid := ParallaxLayer.new()
	mid.name = "ParallaxMid"
	mid.motion_scale = Vector2(0.5, 0.5)
	pb.add_child(mid)

	var mid_map := TileMap.new()
	mid_map.name = "ParallaxMidMap"
	mid_map.set("modulate", Color(0.8, 0.8, 0.9, 0.4))
	mid_map.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mid_mat := CanvasItemMaterial.new()
	mid_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	mid_map.material = mid_mat


	var mid_ts := TileSet.new()
	mid_ts.tile_size = Vector2i(128, 128)
	var blotch_tex := load("res://textures/pushy_ice_tile_14_128_a80.png") as Texture2D
	if blotch_tex:
		var atlas := TileSetAtlasSource.new()
		atlas.texture = blotch_tex
		atlas.texture_region_size = Vector2i(128, 128)
		atlas.create_tile(Vector2i(0, 0))
		mid_ts.add_source(atlas)
	mid_map.tile_set = mid_ts
	mid.add_child(mid_map)

	var tx := int(ceil(world_w / 128.0)) + 2
	var ty := int(ceil(world_h / 128.0)) + 2
	for y in range(-1, ty):
		for x in range(-1, tx):
			if randf() < 0.26:
				mid_map.set_cell(0, Vector2i(x, y), 0, Vector2i(0, 0), 0)

func create_ice_floor() -> void:
	var tilemap := TileMap.new()
	tilemap.name = "TileMapIce"
	tilemap.set("z_index", 1)
	tilemap.set("modulate", Color(1, 1, 1, 0.58))
	tilemap.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nrender_mode blend_mix, unshaded;\nvoid fragment(){\n\tCOLOR *= texture(TEXTURE, UV);\n}\n"
	var sm := ShaderMaterial.new()
	sm.shader = shader
	tilemap.material = sm


	var ts := TileSet.new()
	ts.tile_size = Vector2i(128, 128)
	var textures := [
		"res://textures/pushy_ice_tile_15_128_a80.png",
		"res://textures/pushy_ice_tile_16_128_a80.png",
		"res://textures/pushy_ice_tile_17_128_a80.png",
	]
	var sources: Array[int] = []
	for p in textures:
		var tex := load(p) as Texture2D
		if tex:
			var atlas := TileSetAtlasSource.new()
			atlas.texture = tex
			atlas.texture_region_size = Vector2i(128, 128)
			atlas.create_tile(Vector2i(0, 0))
			var sid := ts.add_source(atlas)
			sources.append(sid)

	tilemap.tile_set = ts
	add_child(tilemap)

	var world_w := int(GameConfig.SCREEN_WIDTH * scale_factor)
	var world_h := int(GameConfig.SCREEN_HEIGHT * scale_factor)
	var tile_w := 128
	var tile_h := 128
	var tiles_x := int(ceil(float(world_w) / float(tile_w))) + 2
	var tiles_y := int(ceil(float(world_h) / float(tile_h))) + 2

	for y in range(-1, tiles_y):
		for x in range(-1, tiles_x):
			var sid := sources[int(randi()) % sources.size()]
			tilemap.set_cell(0, Vector2i(x, y), sid, Vector2i(0, 0), 0)
