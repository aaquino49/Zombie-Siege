class_name FxStrip extends RefCounted
## Atlas cells are shared across every pool slot and scene rebind.

static var _cache: Dictionary = {}

static func frames(strip: Texture2D) -> Array[AtlasTexture]:
	if not _cache.has(strip):
		var cells: Array[AtlasTexture] = []
		for i: int in range(strip.get_width() / Grid.PX_TILE):
			var cell: AtlasTexture = AtlasTexture.new()
			cell.atlas = strip
			cell.region = Rect2(i * Grid.PX_TILE, 0, Grid.PX_TILE, Grid.PX_TILE)
			cell.filter_clip = true
			cells.append(cell)
		_cache[strip] = cells
	return _cache[strip]
