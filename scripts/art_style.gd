class_name SideArtStyle
extends RefCounted

## Shared material language for illustrated actors and scalable object art.
## Presentation only: semantic rarity, warning and damage colors are separate.
const SHADOW := Color("424e55")
const METAL := Color("81999d")
const LIGHT := Color("cbd1bb")
const SIGNAL := Color("94cabb")

static func material(color: Color) -> Color:
	var value: float=maxf(color.r,maxf(color.g,color.b))
	if value<.27:
		return Color("424e55")
	var gray: float=color.r*.25+color.g*.55+color.b*.2
	var softened: Color=color.lerp(Color(gray,gray,gray,color.a),.18)
	if value<.47: softened=softened.lerp(SHADOW,.35)
	return softened

static func svg(source: String) -> String:
	var pattern:=RegEx.new()
	pattern.compile("#[0-9a-fA-F]{6}")
	var replacements: Dictionary={}
	for found: RegExMatch in pattern.search_all(source):
		var code: String=found.get_string()
		replacements[code]="#"+material(Color(code)).to_html(false)
	for code: String in replacements: source=source.replace(code,replacements[code])
	return source.replace('stroke-linecap="square"','stroke-linecap="round"').replace('stroke-linejoin="miter"','stroke-linejoin="round"')

static func path(outline: String, color: String) -> String:
	return '<path d="'+outline+'" fill="#'+color+'"/>'

static func weapon(id: String) -> String:
	var base: String="81999d"
	var light: String="cbd1bb"
	var dark: String="424e55"
	var result: String=""
	match id:
		"pulse_rifle":
			result=path("M-4-4Q0-6 7-3L12-6H27L30-3H36V3H27L23 5H13L10 10H6L7 3L-4 4Z",dark)
			result+=path("M3-3Q12-8 25-4L28-2H35V0H12L8 2H3Z",base)+path("M7-4Q16-6 25-3H13L9-1H5Z",light)
			result+=path("M17-1H29L26 1H17Z","94cabb")
		"scattergun":
			result=path("M-4-3Q0-6 7-2L10-5H21L24-3H38V4H20L16 2L12 10H7L8 2L-4 4Z",dark)
			result+=path("M-3-2L3-3L8 0L3 2H-3Z","b49a78")+path("M8-3Q15-6 23-2H37V0H9Z",light)
			result+=path("M17 0H38V3H19Z",base)
		"railgun":
			result=path("M-5-4L1-5L8-2L12-6H26L31-3H52V4H29L24 6H18L16 11H12V4H8L5 9H2L4 2L-5 4Z",dark)
			result+=path("M3-3Q15-8 27-3L30-1H8Z",base)+path("M8-4Q17-6 25-3H11Z",light)
			result+=path("M29-3H52V-1H29ZM29 1H52V3H29Z","b1c6cc")+path("M30-1H49V1H30Z","91b6c5")
		"flamethrower":
			result=path("M-3-3L5-4L10-6H25L29-3H46V3L28 5L24 3V12Q24 16 18 16Q11 16 11 12V5H9L7 10H3L4 3H-3Z",dark)
			result+=path("M5-3Q14-7 25-3L28 0H7Z","ad9477")+path("M12 5H24V12Q22 15 16 14L12 12Z","b68b65")
			result+=path("M13 6H17V13L14 12Z",light)+path("M28-2H46V2H28Z",base)+path("M42-2H46V2H42Z","d0b58b")
		"arc_blade":
			result=path("M0-3H10L12-7L15-4Q32-6 47 0Q31 7 15 4L12 7L10 3H0Z",dark)
			result+=path("M15-3Q30-5 47 0L32 1H15Z",light)+path("M15 1H32L47 0Q30 6 15 3Z",base)
			result+=path("M11-5H13L15 0L13 5H11L12 0Z","bba17c")+path("M2-1H9V1H2Z","9b917c")
		"boomerang":
			result=path("M2-3H14Q8-11 13-17Q27-12 36 0Q27 12 13 17Q8 11 14 3H2Z",dark)
			result+=path("M14-14Q27-9 35 0L27-1Q20-5 14-10Z",light)+path("M14 14Q27 9 35 0L27 1Q20 5 14 10Z",base)
			result+=path("M4-1H26L36 0L26 1H4Z","94cabb")
		"storm_staff":
			result=path("M-2-3H29Q29-13 39-13Q47-13 48-5L44-4Q42-9 38-8L35-3H48V3H35L38 8Q42 9 44 4L48 5Q47 13 39 13Q29 13 29 3H-2Z",dark)
			result+=path("M0-2H32V0H0ZM33-5Q34-12 42-10L45-7Q36-9 36-3Z",light)+path("M33 5Q34 12 42 10L45 7Q36 9 36 3Z",base)
			result+=path("M35-1H48V1H35Z","94cabb")
		"sun_lance":
			result=path("M-4-2H26L29-7H33L35-4Q46-6 58 0Q46 6 35 4L33 7H29L26 2H-4Z",dark)
			result+=path("M-3-1H29V1H-3Z","b9a785")+path("M33-3Q46-5 58 0L43 0H33Z",light)+path("M33 0H58Q46 5 33 3Z",base)
			result+=path("M29-5H32L30 0L32 5H29L27 0Z","d2b787")
	return result

static func facility(kind: String,state: String) -> String:
	var dark: String="424e55"
	var mid: String="829796"
	var light: String="cbd1bb"
	var result: String=""
	match kind:
		"cache":
			result=path("M-27-13Q-28-22-18-25H18Q28-22 27-13V3Q24 9 17 9H-17Q-24 9-27 3Z",dark)
			result+=path("M-24-12H24V2Q18 6 0 6Q-18 6-24 2Z","a18e74")
			result+=path("M-23-12Q-26-24-14-26H14Q26-24 23-12Z",light)
			result+=path("M-23-12H23V-7H-23Z",mid)+path("M-4-14H4L6-4L0 0L-6-4Z",dark)
			result+='<path d="M-2-11H2V-5H-2Z" fill="ACCENT"/>'
			if state=="open":
				result+=path("M-23-13Q-28-35-15-42H15Q28-35 23-13L18-19H-18Z",mid)+path("M-18-31Q0-41 18-31V-22H-18Z",dark)+path("M-23-13H23V-7H-23Z",dark)
		"choice":
			result=path("M-27 8Q-21 1-13 1L-10-15H10L13 1Q21 1 27 8Z",dark)+path("M-21 5H21L24 8H-24Z",light)
			result+=path("M-10 1L-7-14H7L10 1Z",mid)+path("M-18-18Q0-12 18-18L14-12Q0-7-14-12Z",light)
			result+='<path d="M-12-17Q0-14 12-17L10-14H-10Z" fill="ACCENT"/>'
		"blood":
			result=path("M-26 8Q-18 3-17-5Q-22-32-5-45Q-14-26-9-6L-4 2H4L9-6Q14-26 5-45Q22-32 17-5Q18 3 26 8Z",dark)
			result+=path("M-20 2Q-22-26-7-40Q-16-23-13-6L-8 2ZM20 2Q22-26 7-40Q16-23 13-6L8 2Z",mid)
			result+=path("M0-34Q13-21 8-9Q0 3-8-9Q-13-21 0-34Z","9f7276")
			result+='<path d="M0-29Q-7-19-4-12Q0-9 2-15L4-22Z" fill="ACCENT"/>'
			result+=path("M-22 5H22L26 8H-26Z",light)
		"combat":
			result=path("M-26 8L-18 2Q-24-22-13-35L-4-40L0-28L4-40L13-35Q24-22 18 2L26 8Z",dark)
			result+=path("M-17 1Q-20-21-11-31L-7-25L-10-8L0-2L10-8L7-25L11-31Q20-21 17 1Z",mid)
			result+=path("M-11-31L-7-25L-10-16L-15-20ZM11-31L7-25L10-16L15-20Z",light)
			result+='<path d="M-7-19L0-12L7-19L5-9L0-5L-5-9Z" fill="ACCENT"/>'
		"equipment":
			result=path("M-27 7V-26Q-27-43-14-45H14Q27-43 27-26V7Z",dark)
			result+=path("M-23 3V-26Q-23-39-13-41H13Q23-39 23-26V3H16V-24Q16-33 9-34H-9Q-16-33-16-24V3Z",mid)
			result+=path("M-20-30Q-19-40-9-40H9Q19-40 20-30L14-34H-14Z",light)
			result+='<path d="M-21-26H-18V0H-21ZM18-26H21V0H18Z" fill="ACCENT"/>'
			result+=path("M-24 3H24V8H-24Z",light)
			if state=="open": result+=path("M-15-25L-27-30V-7L-15-3ZM15-25L27-30V-7L15-3Z",mid)
	if state=="locked": result+='<path d="M-5-11V-16Q0-23 5-16V-11M-7-11H7V0H-7Z" fill="#6a7d81" stroke="#cbd1bb" stroke-width="2"/>'
	elif state=="open" and kind!="cache": result+='<path d="M-5-8L-1-4L7-13" fill="none" stroke="#b5c9b7" stroke-width="2"/>'
	elif state=="active": result+='<path d="M-18-23L-14-19L-18-15ZM18-23L14-19L18-15Z" fill="ACCENT"/>'
	return result
