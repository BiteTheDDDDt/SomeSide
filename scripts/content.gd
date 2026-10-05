class_name SideContent
extends RefCounted

static var _definitions: Dictionary = {}

static func passives() -> Array:
	return [
		_record("overclock", "超频芯片", "每层 +13% 普通攻击速度。", "67e5ef", "passive"),
		_record("capacitor", "裂变电容", "每层 +12% 伤害，武器与伤害型主动装备均生效。", "ffd06f", "passive"),
		_record("lens", "棱镜目镜", "每层 +8% 暴击率（上限85%）；暴击造成双倍伤害。", "ff84be", "passive"),
		_record("vitality", "共生核心", "每层 +25 基础最大生命，获得时回复增加的生命；受脆晶倍率影响。", "98e39b", "passive"),
		_record("thruster", "矢量推进器", "每层 +9% 移速，并缩短冲刺冷却。", "a0b4ff", "passive"),
		_record("arc", "电弧线圈", "命中概率向最多3个邻敌弹射电弧；叠层提高概率和伤害，电弧不再次触发。", "9bf5ff", "passive", "rare"),
		_record("ember", "余烬孢子", "直接击杀产生115范围爆炸；每层 +9 爆炸伤害，连锁击杀不再爆炸。", "ff8b61", "passive", "rare"),
		_record("moss", "星苔", "每层每秒回复0.65生命；5秒未受伤时翻倍。", "b6e89f", "passive"),
		_record("siphon", "虹吸针", "每层击杀回复1.8生命。", "de8be4", "passive"),
		_record("coolant", "低温回路", "每层缩短主动装备冷却；最低为基础冷却的35%。", "90caff", "passive"),
		_record("feather", "跃迁羽翼", "每层增加1次空中跳跃。落地后恢复所有跳跃次数，可跨越阶梯走捷径。", "e1f1ff", "passive", "rare"),
		_record("glass", "脆晶契约", "每层 +30% 伤害；每层将最大生命乘以0.85（最低为角色基础生命的20%）。", "fa80a1", "passive", "rare", "代价：立即降低最大生命！当前生命超过新上限时会被截断；叠层会继续降低。"),
		_record("plating", "陶瓷装甲", "每层抵消1点受到的伤害，最多抵消该次伤害的60%。", "c7d0d5", "passive"),
		_record("magnet", "牵引磁环", "每层增加35范围的治疗自动收集距离，上限350；金币自动到账，遗物仍需手动拾取。", "c7d0d5", "passive"),
		_record("harvest", "丰收协议", "击杀金币每层增加15%，最多翻倍；采用存活队员的最高加成，全队自动到账。首领固定奖金不加成。", "7fd4a0", "passive", "uncommon"),
		_record("battery", "静息电池", "6秒未受伤后每秒恢复护盾，每层最高8点；总上限为最大生命60%。", "7fd4a0", "passive", "uncommon"),
		_record("frost", "霜凝结晶", "直接命中使敌人减速1.5秒；首层20%，每额外层+5%，上限50%。", "7fd4a0", "passive", "uncommon"),
		_record("momentum", "惯性飞轮", "冲刺后1.2秒内每层 +15%伤害，最多+60%。", "7fd4a0", "passive", "uncommon"),
		_record("toxin", "蚀骨菌株", "直接命中附加4秒中毒，每层每秒3伤害，最多按8层计算；持续伤害不触发连锁。", "b49af5", "passive", "rare"),
		_record("echo", "第六回声", "每第6次普通攻击追加自动共鸣打击，每层12伤害（最多8层），搜索范围650。", "b49af5", "passive", "rare"),
		_record("piercer", "穿界针", "非爆炸弹丸每层多穿透1个目标，最多增加3次；同次飞行不重复命中。", "b49af5", "passive", "rare"),
		_record("resonator", "广域共鸣器", "首层使自己的伤害爆炸半径增加30%，后续每层再增加10%，最多增加80%。", "ffd071", "passive", "legendary"),
		_record("phoenix", "不灭余火", "每层每关可抵挡1次致命伤（最多2次），恢复35%生命并获得2秒无敌。", "ffd071", "passive", "legendary"),
		_record("nova", "超新星种子", "直接暴击释放130范围新星，每层16伤害（最多8层）；0.75秒内置冷却，不递归触发。", "ffd071", "passive", "legendary"),
	]

static func weapons() -> Array:
	var result: Array = [
		_record("pulse_rifle", "脉冲步枪", "精准持续射击：每发8伤害，基础间隔0.19秒；中远距离稳定火力。", "65e2d6", "weapon"),
		_record("arc_blade", "共鸣弧刃", "定向近战扇形斩击：基础24伤害，间隔0.52秒；每命中一敌回复0.35生命。", "ffa66a", "weapon"),
		_record("scattergun", "裂片霰弹枪", "一次发射6枚散射弹，每枚8伤害，间隔0.60秒；射程约350，贴近目标威力更强。", "ffc975", "weapon", "rare"),
		_record("railgun", "穿星磁轨枪", "高能直线穿透弹：基础70伤害，间隔1.05秒；最多穿透3个敌人，射程1500。", "b69fff", "weapon", "rare"),
		_record("flamethrower", "熔火喷流", "170范围火焰锥，每0.12秒造成8伤害，并点燃目标：每秒5伤害，持续2秒。", "7fd4a0", "weapon", "uncommon"),
		_record("boomerang", "回旋星刃", "投出返航刃：每次命中26伤害，往返各可穿透4个目标；间隔0.65秒。", "b49af5", "weapon", "rare"),
		_record("storm_staff", "万雷权杖", "每0.48秒发射32伤害雷球，再向两个邻敌各弹射20伤害；多目标压制。", "ffd071", "weapon", "legendary"),
		_record("sun_lance", "恒星长矛", "每0.85秒发射120伤害光矛，最多穿透6敌；每次命中另有70范围22伤害爆裂。", "ffd071", "weapon", "legendary"),
	]
	var intervals: Array[float] = [0.19, 0.52, 0.60, 1.05, 0.12, 0.65, 0.48, 0.85]
	for index in range(result.size()):
		result[index]["fire_interval"] = intervals[index]
	return result

static func equipment() -> Array:
	var result: Array = [
		_record("grenade", "震荡手雷", "朝瞄准方向投掷：触敌、落地或0.95秒后爆炸，135范围内基础70伤害。基础冷却8秒。", "f7b36b", "equipment"),
		_record("shockwave", "裂地冲击", "向瞄准方向突袭，150范围内基础60伤害，并获得0.45秒无敌。基础冷却9秒。", "ff8e79", "equipment"),
		_record("repair_field", "共生修复场", "立即为260范围内自己与存活队友各回复35%最大生命。基础冷却14秒。", "91e1a6", "equipment", "rare"),
		_record("aegis", "相位护盾", "获得相当于最大生命60%的护盾，持续6秒，并获得0.4秒无敌。基础冷却12秒。", "86c9ff", "equipment", "rare"),
		_record("graviton", "引力囚笼", "牵引瞄准点300范围敌人并造成55伤害、定身1.4秒；Boss定身0.45秒。冷却13秒。", "b49af5", "equipment", "rare"),
		_record("turret", "哨戒构装", "部署持续8秒炮台，每0.35秒自动向650范围最近敌人发射14伤害弹；最多同时4台。冷却18秒。", "b49af5", "equipment", "rare"),
		_record("meteor", "天穹陨击", "朝瞄准方向300距离召来3次延迟陨击，每次150范围140伤害。冷却22秒。", "ffd071", "equipment", "legendary"),
		_record("time_warp", "时序王冠", "让350范围内存活队友获得5秒时序加速：攻击速度+60%、移速+30%，并短暂无敌。冷却24秒。", "ffd071", "equipment", "legendary"),
	]
	var cooldowns: Array[float] = [8.0, 9.0, 14.0, 12.0, 13.0, 18.0, 22.0, 24.0]
	for index in range(result.size()):
		result[index]["cooldown"] = cooldowns[index]
	return result

static func definition(id: String) -> Dictionary:
	if _definitions.is_empty():
		for catalog in [passives(), weapons(), equipment()]:
			for record: Dictionary in catalog:
				_definitions[str(record.id)] = record
	# Keep the public API isolated: callers may annotate their own copy.
	# Records contain only value types, so a shallow copy is sufficient.
	return Dictionary(_definitions.get(id, {})).duplicate()

static func _record(id: String, title: String, description: String, color: String, category: String, rarity: String = "common", warning: String = "") -> Dictionary:
	if id in ["lens", "ember", "siphon", "coolant", "scattergun", "repair_field"]:
		rarity = "uncommon"
	return {"id": id, "name": title, "description": description, "color": rarity_color(rarity), "theme_color": Color(color), "category": category, "rarity": rarity, "warning": warning}

static func rarity_name(rarity: String) -> String:
	return {"common": "普通", "uncommon": "精良", "rare": "稀有", "legendary": "传说"}.get(rarity, "普通")

static func rarity_color(rarity: String) -> Color:
	return Color({"common": "c7d0d5", "uncommon": "7fd4a0", "rare": "b49af5", "legendary": "ffd071"}.get(rarity, "c7d0d5"))

static func rarity_rank(rarity: String) -> int:
	return int({"common": 0, "uncommon": 1, "rare": 2, "legendary": 3}.get(rarity, 0))
