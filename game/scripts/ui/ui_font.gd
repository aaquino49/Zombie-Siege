class_name UiFont

const NATIVE := 11
const SMALL := 11
const BODY := 22
const LARGE := 33
const TITLE := 44
const BANNER := 66

static func is_crisp(size: int) -> bool:
	return size > 0 and size % NATIVE == 0
