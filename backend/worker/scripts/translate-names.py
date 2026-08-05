#!/usr/bin/env python3
"""Build Chinese names for the exercise catalogue.

Deterministic rather than model-generated: the same English term always maps to
the same Chinese one, which matters when 1324 names sit next to each other in a
list. Multi-word idioms are matched first (a "lat pulldown" is 高位下拉, not
"背阔肌 下拉"), then the remainder is translated token by token.

Reports coverage so the leftovers can be fixed by hand instead of shipping
half-English names silently.
"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Idioms — matched before single words, longest first.
PHRASES = {
    "balance board": "平衡板",
    "wobble board": "平衡板",
    "lat pulldown": "高位下拉",
    "hip thrust": "臀推",
    "good morning": "早安式体前屈",
    "romanian deadlift": "罗马尼亚硬拉",
    "stiff leg deadlift": "直腿硬拉",
    "sumo deadlift": "相扑硬拉",
    "hack squat": "哈克深蹲",
    "sissy squat": "西西里深蹲",
    "front squat": "前蹲",
    "goblet squat": "高脚杯深蹲",
    "split squat": "分腿蹲",
    "bulgarian split squat": "保加利亚分腿蹲",
    "box squat": "箱式深蹲",
    "wall squat": "靠墙静蹲",
    "pistol squat": "单腿深蹲",
    "cossack squat": "哥萨克深蹲",
    "zercher squat": "泽奇深蹲",
    "bench press": "卧推",
    "incline bench press": "上斜卧推",
    "decline bench press": "下斜卧推",
    "close grip bench press": "窄距卧推",
    "military press": "军事推举",
    "arnold press": "阿诺德推举",
    "overhead press": "过顶推举",
    "shoulder press": "肩推",
    "chest press": "胸推",
    "leg press": "腿举",
    "calf press": "提踵",
    "leg extension": "腿屈伸",
    "leg curl": "腿弯举",
    "leg raise": "举腿",
    "hip abduction": "髋外展",
    "hip adduction": "髋内收",
    "hip extension": "髋伸展",
    "back extension": "背伸展",
    "lateral raise": "侧平举",
    "front raise": "前平举",
    "rear delt": "后束",
    "rear delt fly": "后束飞鸟",
    "reverse fly": "反向飞鸟",
    "upright row": "直立划船",
    "bent over row": "俯身划船",
    "bent-over row": "俯身划船",
    "seated row": "坐姿划船",
    "t-bar row": "T杠划船",
    "pendlay row": "彭德利划船",
    "face pull": "面拉",
    "pull-up": "引体向上",
    "pull up": "引体向上",
    "chin-up": "反握引体向上",
    "chin up": "反握引体向上",
    "muscle-up": "双力臂",
    "push-up": "俯卧撑",
    "push up": "俯卧撑",
    "sit-up": "仰卧起坐",
    "sit up": "仰卧起坐",
    "v-up": "V字卷腹",
    "v-sit": "V字支撑",
    "step-up": "台阶上步",
    "step up": "台阶上步",
    "skull crusher": "颈后臂屈伸",
    "skullcrusher": "颈后臂屈伸",
    "tricep extension": "三头肌伸展",
    "triceps extension": "三头肌伸展",
    "triceps pushdown": "三头肌下压",
    "tricep pushdown": "三头肌下压",
    "hammer curl": "锤式弯举",
    "preacher curl": "牧师凳弯举",
    "concentration curl": "集中弯举",
    "zottman curl": "佐特曼弯举",
    "wrist curl": "腕弯举",
    "russian twist": "俄罗斯转体",
    "mountain climber": "登山跑",
    "jumping jack": "开合跳",
    "burpee": "波比跳",
    "farmers walk": "农夫行走",
    "turkish get up": "土耳其起立",
    "clean and jerk": "挺举",
    "power clean": "高翻",
    "snatch": "抓举",
    "thruster": "推举深蹲",
    "kettlebell swing": "壶铃摆荡",
    "battling ropes": "战绳",
    "battle ropes": "战绳",
    "medicine ball": "药球",
    "stability ball": "健身球",
    "bosu ball": "波速球",
    "foam roll": "泡沫轴放松",
    "jump rope": "跳绳",
    "high knee": "高抬腿",
    "flutter kick": "交替打腿",
    "scissor kick": "剪刀腿",
    "donkey kick": "驴踢腿",
    "glute bridge": "臀桥",
    "pelvic tilt": "骨盆倾斜",
    "dead bug": "死虫式",
    "bird dog": "鸟狗式",
    "plank": "平板支撑",
    "side plank": "侧平板支撑",
    "hanging leg raise": "悬垂举腿",
    "inverted row": "反向划船",
    "shrug": "耸肩",
    "dip": "双杠臂屈伸",
    "dips": "双杠臂屈伸",
    "crunch": "卷腹",
    "crunches": "卷腹",
    "lunge": "弓步",
    "curtsey lunge": "屈膝礼弓步",
    "walking lunge": "行进弓步",
    "reverse lunge": "后撤弓步",
    "side lunge": "侧弓步",
    "calf raise": "提踵",
    "toe raise": "勾脚尖",
    "shoulder shrug": "耸肩",
    "pull down": "下拉",
    "pulldown": "下拉",
    "pullover": "屈臂上拉",
    "fly": "飞鸟",
    "flyes": "飞鸟",
    "flys": "飞鸟",
    "crossover": "夹胸",
    "crossovers": "夹胸",
    "kickback": "后踢",
    "kickbacks": "后踢",
    "roll out": "滚轮",
    "rollout": "滚轮",
    "rollerout": "滚轮",
    "get up": "起立",
    "sled": "雪橇",
    "handstand": "倒立",
    "l-sit": "L支撑",
    "windmill": "风车式",
    "superman": "超人式",
    "swimmer": "游泳式",
    "inchworm": "毛毛虫爬行",
    "bear crawl": "熊爬",
    "crab walk": "螃蟹走",
    "wall ball": "墙球",
    "landmine": "杠铃杆旋转",
    "pallof press": "帕洛夫推",
    "svend press": "夹胸推",
    "jm press": "JM推举",
    "bradford press": "布拉德福德推举",
    "tate press": "泰特推举",
    "spider curl": "蜘蛛弯举",
    "drag curl": "拖拽弯举",
    "reverse curl": "反握弯举",
    "cuban rotation": "古巴旋转",
    "scapular retraction": "肩胛回缩",
    "ski ergometer": "滑雪机",
    "stepmill": "登山机",
    "treadmill": "跑步机",
    "elliptical": "椭圆机",
    "stationary bike": "动感单车",
    "rowing": "划船",
    "run": "跑步",
    "walk": "走路",
    "sprint": "冲刺跑",
    "stretch": "拉伸",
}

# Single tokens.
WORDS = {
    # equipment
    "dumbbell": "哑铃", "dumbbells": "哑铃", "barbell": "杠铃", "ez-barbell": "EZ杠",
    "ez": "EZ杠", "ez-bar": "EZ杠", "sz-bar": "SZ杠", "cambered": "曲杆",
    "cable": "绳索", "band": "弹力带", "resistance": "弹力带", "kettlebell": "壶铃",
    "smith": "史密斯机", "lever": "器械", "machine": "器械", "sled": "雪橇",
    "ball": "球", "bosu": "波速球", "roller": "滚轮", "wheel": "滚轮",
    "rope": "绳", "ropes": "绳", "bar": "杠", "bars": "双杠", "t-bar": "T杠",
    "v-bar": "V杠", "bodyweight": "自重", "body": "身体", "weighted": "负重",
    "assisted": "辅助", "suspended": "悬吊", "suspension": "悬吊", "trainer": "训练器",
    "strap": "绳带", "straps": "绳带", "towel": "毛巾", "chair": "椅子",
    "bench": "长凳", "benches": "长凳", "box": "跳箱", "stepbox": "踏板",
    "platform": "踏板", "board": "平衡板", "wall": "墙", "floor": "地面",
    "cage": "深蹲架", "rack": "架", "pulley": "滑轮", "attachment": "把手",
    "handle": "把手", "gripper": "握力器", "blaster": "臂弯举器", "pin": "插销",
    "stirrups": "脚蹬", "captains": "队长椅", "ring": "吊环", "tire": "轮胎",
    "sledge": "大锤", "yoga": "瑜伽", "slide": "滑板", "equipment": "器械",
    "fixed": "固定", "stationary": "固定", "bike": "单车", "skier": "滑雪机",
    "ergometer": "测功仪", "trap": "六角杠", "olympic": "奥林匹克",
    # movements
    "curl": "弯举", "curls": "弯举", "curl-up": "卷腹", "press": "推举",
    "presses": "推举", "raise": "上举", "raises": "上举", "row": "划船",
    "squat": "深蹲", "squats": "深蹲", "squatting": "深蹲", "squad": "深蹲",
    "deadlift": "硬拉", "lunge": "弓步", "extension": "伸展", "flexion": "屈曲",
    "push": "推", "pull": "拉", "pull-in": "收腹", "pull-ups": "引体向上",
    "chin-ups": "反握引体向上", "l-pull-up": "L引体向上", "jump": "跳跃",
    "jumps": "跳跃", "hops": "跳跃", "twist": "转体", "twists": "转体",
    "twisting": "转体", "twisted": "转体", "rotation": "旋转", "rotational": "旋转",
    "rotary": "旋转", "rotate": "旋转", "circles": "绕环", "circular": "绕环",
    "swing": "摆荡", "throw": "投掷", "slam": "砸", "clean": "翻",
    "jerk": "挺", "snatch": "抓举", "shrug": "耸肩", "dip": "臂屈伸",
    "dips": "臂屈伸", "crunch": "卷腹", "crunches": "卷腹", "bridge": "臀桥",
    "plank": "平板支撑", "hang": "悬垂", "hanging": "悬垂", "climb": "攀爬",
    "climber": "登山", "crawl": "爬行", "walk": "行走", "walking": "行走",
    "march": "原地踏步", "run": "跑", "runners": "跑者", "sprint": "冲刺",
    "sprints": "冲刺", "kick": "踢", "kicks": "踢", "tap": "点地",
    "touch": "触碰", "touchers": "触碰", "reach": "伸够", "carry": "行走搬运",
    "drive": "驱动", "drag": "拖拽", "flip": "翻转", "lift": "上提",
    "lifting": "上提", "bend": "俯身", "bends": "俯身", "stretch": "拉伸",
    "squeeze": "夹紧", "hug": "抱", "pass": "传递", "release": "释放",
    "catch": "接", "saw": "推拉", "pike": "屈体", "tuck": "收膝",
    "fallout": "前推", "thrusts": "顶髋", "thruster": "推举深蹲",
    "abduction": "外展", "adduction": "内收", "pronation": "旋前",
    "supination": "旋后", "hyperextension": "过伸", "hyper": "过伸",
    "isometric": "静力", "burpee": "波比跳", "jack": "开合跳",
    "get": "起立", "up-down": "起落", "ups": "起身", "down": "下",
    "up": "上", "step-up": "台阶上步", "step": "台阶",
    # body parts
    "chest": "胸", "pectoralis": "胸肌", "pec": "胸肌", "back": "背",
    "lat": "背阔肌", "shoulder": "肩", "deltoid": "三角肌", "delt": "三角肌",
    "arm": "臂", "arms": "臂", "biceps": "二头肌", "bicep": "二头肌",
    "triceps": "三头肌", "tricep": "三头肌", "forearm": "前臂", "wrist": "腕",
    "elbow": "肘", "finger": "手指", "hand": "手", "hands": "手",
    "palm": "手掌", "palms": "手掌", "leg": "腿", "legs": "腿",
    "legged": "腿", "quad": "股四头肌", "quads": "股四头肌", "hamstring": "腘绳肌",
    "femoral": "股", "femoris": "股直肌", "rectus": "腹直肌", "glute": "臀",
    "glutes": "臀", "gluteus": "臀肌", "calf": "小腿", "calves": "小腿",
    "ankle": "踝", "ankles": "踝", "heel": "脚跟", "toe": "脚尖",
    "feet": "脚", "knee": "膝", "knees": "膝", "keens": "膝",
    "hip": "髋", "groin": "内收肌", "abdominal": "腹", "ab": "腹",
    "oblique": "腹斜肌", "core": "核心", "neck": "颈", "head": "头",
    "spine": "脊柱", "scapula": "肩胛", "scapular": "肩胛", "piriformis": "梨状肌",
    "tibialis": "胫骨前肌", "peroneals": "腓骨肌", "adductor": "内收肌",
    "abductor": "外展肌", "flexor": "屈肌", "posterior": "后侧", "anti": "抗",
    "major": "大肌", "muscle": "肌肉", "face": "面",
    # modifiers
    "seated": "坐姿", "sitted": "坐姿", "sit": "坐", "standing": "站姿",
    "stance": "站距", "lying": "仰卧", "supine": "仰卧", "prone": "俯卧",
    "kneeling": "跪姿", "incline": "上斜", "decline": "下斜", "flat": "平板",
    "reverse": "反向", "reversed": "反向", "revers": "反向", "reverse-grip": "反握",
    "underhand": "反握", "overhand": "正握", "pronated": "正握", "supinated": "反握",
    "pronate-grip": "正握", "neutral": "对握", "palm-in": "对握",
    "close": "窄距", "close-grip": "窄距", "narrow": "窄距", "closer": "窄距",
    "wide": "宽距", "wide-grip": "宽距", "grip": "握法", "gripless": "无握",
    "mixed": "交叉握", "clean-grip": "翻握",
    "alternate": "交替", "alternating": "交替", "single": "单侧",
    "unilateral": "单侧", "one": "单", "two": "双", "two-one": "双起单落",
    "double": "双", "twin": "双", "both": "双", "one-arm": "单臂",
    "front": "前", "rear": "后", "side": "侧", "lateral": "侧",
    "side-to-side": "左右", "cross": "交叉", "cross-over": "交叉",
    "contralateral": "对侧", "diagonal": "斜向", "forward": "向前",
    "backward": "向后", "upward": "向上", "vertical": "垂直",
    "horizontal": "水平", "parallel": "平行", "inverted": "倒立",
    "inverse": "反向", "inner": "内侧", "outer": "外侧", "inside": "内",
    "outside": "外", "internal": "内旋", "external": "外旋",
    "high": "高位", "low": "低位", "middle": "中位", "半": "半",
    "half": "半程", "quarter": "四分之一", "full": "全程", "partial": "半程",
    "deep": "深", "short": "短", "long": "长", "wide-stance": "宽站距",
    "sumo": "相扑", "straight": "直", "stiff": "直腿", "bent": "屈",
    "bent-over": "俯身", "bent-knee": "屈膝", "extended": "伸展",
    "raised": "抬高", "elevated": "抬高", "supported": "支撑",
    "support": "支撑", "self": "自主", "assisted": "辅助", "with": "配合",
    "on": "在", "over": "过", "under": "下", "behind": "颈后", "above": "上方",
    "against": "对抗", "between": "之间", "around": "环绕", "through": "穿过",
    "across": "跨越", "into": "至", "to": "至", "from": "从", "off": "离",
    "and": "与", "the": "", "a": "", "of": "", "in": "", "at": "",
    "male": "男式", "female": "女式", "pov": "", "exercise": "训练",
    "variation": "变式", "modified": "改良", "advanced": "进阶",
    "intermediate": "中级", "basic": "基础", "pro": "专业", "power": "爆发",
    "speed": "快速", "quick": "快速", "slow": "慢速", "dynamic": "动态",
    "static": "静态", "negative": "离心", "eccentric": "离心",
    "stabilization": "稳定", "balance": "平衡", "motion": "活动",
    "range": "幅度", "angle": "角度", "angled": "倾斜", "degrees": "度",
    "position": "姿势", "pose": "姿势", "style": "式", "sequence": "组合",
    "multiple": "多次", "reps": "次", "three": "三", "all": "全",
    "fours": "四点", "star": "星式", "world": "世界", "greatest": "最佳",
    "45": "45度", "180": "180度", "360": "360度", "2": "二", "3": "三",
    "8": "八", "v": "V字", "t": "T字", "y-raise": "Y字上举", "t-raise": "T字上举",
    "w-press": "W推举", "l-sit": "L支撑", "figure": "字形",
}

# Second pass: everything the first coverage run flagged.
WORDS.update({
    "overhead": "过顶", "hammer": "锤式", "s": "", "-": "", "d": "", "ing": "",
    "lower": "下部", "upper": "上部", "pushdown": "下压", "planche": "俯卧撑支撑",
    "donkey": "驴式", "archer": "射箭式", "drop": "递减", "french": "法式",
    "zottman": "佐特曼", "plyo": "爆发", "frog": "蛙式", "chin": "反握",
    "slingers": "摆动", "jm": "JM", "rocky": "洛奇", "rocking": "摇摆",
    "stork": "single-leg", "cuban": "古巴", "iron": "铁质", "sphinx": "斯芬克斯",
    "otis": "奥蒂斯", "gironda": "吉隆达", "hindu": "印度式", "judo": "柔道",
    "kayak": "皮划艇", "korean": "韩式", "london": "伦敦", "maltese": "马耳他",
    "monster": "怪兽", "peacher": "牧师凳", "scott": "斯科特", "thibaudeau": "蒂博多",
    "waiter": "侍者", "zercher": "泽奇", "svend": "夹胸", "tate": "泰特",
    "bradford": "布拉德福德", "pallof": "帕洛夫", "russian": "俄罗斯",
    "turkish": "土耳其", "bulgarian": "保加利亚", "romanian": "罗马尼亚",
    "arnold": "阿诺德", "pendlay": "彭德利", "sissy": "西西里", "hack": "哈克",
    "goblet": "高脚杯", "cossack": "哥萨克", "curtsey": "屈膝礼", "farmers": "农夫",
    "renegade": "叛徒", "janda": "扬达", "hyght": "海特", "frankenstein": "科学怪人",
    "gorilla": "大猩猩", "spider": "蜘蛛", "butterfly": "蝴蝶", "bowling": "保龄球",
    "breeding": "繁殖式", "clap": "击掌", "clock": "时钟", "cocoons": "蜷缩",
    "crab": "螃蟹", "cycle": "循环", "diamond": "钻石", "elevator": "电梯式",
    "flag": "旗式", "flutter": "交替", "ground": "地面", "guillotine": "断头台",
    "impossible": "高难", "jackknife": "折刀", "jefferson": "杰斐逊",
    "kipping": "借力", "knife": "折刀", "lean": "前倾", "left": "左",
    "hook": "钩", "boxing": "拳击", "mountain": "登山", "pirate": "海盗",
    "pistol": "手枪式", "potty": "深蹲坐", "prisoner": "囚徒", "pyramid": "金字塔",
    "response": "反应", "ring": "吊环", "rollerer": "滚轮", "round": "圆背",
    "saw": "推拉", "scissor": "剪刀", "seesaw": "跷跷板", "semi": "半",
    "skater": "滑冰式", "ski": "滑雪", "skin": "翻越", "cat": "猫式",
    "sledge": "大锤", "spell": "拼写", "caster": "施法者", "stalder": "斯塔尔德",
    "staircase": "楼梯", "straddle": "分腿", "stride": "跨步", "sumo": "相扑",
    "supper": "晚餐", "swimmer": "游泳", "tennis": "网球", "thrusts": "顶髋",
    "tuck": "收膝", "vertical": "垂直", "wipers": "雨刷", "yoga": "瑜伽",
    "big": "大", "bug": "虫式", "bottoms-up": "底朝上", "bottoms": "底部",
    "butt-ups": "抬臀", "body-up": "起身", "dip-pull-up": "臂屈伸引体",
    "elbow-to-knee": "肘碰膝", "glute-ham": "臀腿", "l-pull-up": "L引体向上",
    "pike-to-cobra": "屈体转眼镜蛇", "side-to-side": "左右", "t-raise": "T字上举",
    "up-down": "起落", "v-up": "V字卷腹", "w-press": "W推举", "y-raise": "Y字上举",
    "outstretched": "伸直", "reclining": "仰卧", "clasped": "交扣",
    "depresor": "下压", "retractor": "回缩", "astride": "跨坐", "apart": "分开",
    "forth": "向前", "backward": "向后", "dead": "静止", "deep": "深",
    "depth": "深度", "quarter": "四分之一", "air": "徒手", "all": "全",
    "fours": "四点支撑", "heel": "脚跟", "point": "点", "pin": "插销",
    "modified": "改良", "basic": "基础", "advanced": "进阶",
    "intermediate": "中级", "variation": "变式", "isometric": "静力",
})

# Third pass: the one-and-two-occurrence tail.
WORDS.update({
    "out": "外", "leg-hip": "腿髋", "3/4": "四分之三", "bicycle": "单车式",
    "skull": "颈后", "butter": "蝴蝶", "concentration": "集中", "can": "罐式",
    "upright": "直立", "gravity": "重力", "sternum": "胸骨", "l-": "L",
    "pad": "垫", "plus": "加强", "oid": "", "ners": "", "ed": "", "ge": "",
    "facing": "朝向", "dog": "犬式", "wind": "风车",
})



def translate(name: str) -> tuple[str, list[str]]:
    """Returns (chinese, untranslated_tokens)."""
    text = name.lower().strip()

    # Longest phrases first so "incline bench press" beats "bench press".
    for phrase in sorted(PHRASES, key=len, reverse=True):
        if phrase in text:
            text = text.replace(phrase, " " + PHRASES[phrase] + " ")

    out: list[str] = []
    missing: list[str] = []
    for chunk in text.split(" "):
        if not chunk:
            continue
        if re.search(r"[一-鿿]", chunk):
            out.append(chunk)
            continue
        for token in re.findall(r"[a-z0-9/'-]+", chunk):
            if token in WORDS:
                if WORDS[token]:
                    out.append(WORDS[token])
            else:
                missing.append(token)
                out.append(token)
    # Token substitution can emit the same word twice — "balance" followed by
    # "balance board" reads as 平衡平衡板. Collapse neighbouring duplicates.
    deduped: list[str] = []
    for piece in out:
        if deduped and (piece == deduped[-1] or piece in deduped[-1]):
            continue
        if deduped and deduped[-1] in piece:
            deduped[-1] = piece
            continue
        deduped.append(piece)
    return "".join(deduped), missing


def main() -> int:
    catalog = json.loads((ROOT / "data" / "exercises.json").read_text())
    names: dict[str, str] = {}
    missing_counts: dict[str, int] = {}

    for item in catalog["exercises"]:
        zh, missing = translate(item["name"])
        names[item["id"]] = zh
        for token in missing:
            missing_counts[token] = missing_counts.get(token, 0) + 1

    out = ROOT / "data" / "exercise-names.zh.json"
    out.write_text(json.dumps(names, ensure_ascii=False, indent=0))

    clean = sum(1 for v in names.values() if not re.search(r"[a-z]", v, re.I))
    print(f"翻译 {len(names)} 条，全中文 {clean} 条（{clean / len(names):.1%}）")
    if missing_counts:
        top = sorted(missing_counts.items(), key=lambda kv: -kv[1])[:25]
        print("未覆盖的词（按出现次数）:", top)
    return 0


if __name__ == "__main__":
    sys.exit(main())
