import SwiftUI

// MARK: - 辅食推荐（按月龄）

struct BabyFood: Identifiable {
    var id: String { name }  // 同一阶段内名称唯一
    let name: String
    let img: String          // 食材图片资源名（Assets.xcassets）
    let benefit: String      // 对宝宝的作用 / 健康好处
    let bestTime: String     // 建议食用时段
    let steps: [String]      // 烹饪步骤
    let note: String?       // 小提示

    init(name: String, img: String, benefit: String, bestTime: String, steps: [String], note: String? = nil) {
        self.name = name; self.img = img; self.benefit = benefit
        self.bestTime = bestTime; self.steps = steps; self.note = note
    }
}

struct FoodStage: Identifiable {
    let id: Int
    let label: String       // "6-7 月龄"
    let subtitle: String    // 阶段特点
    let feeding: String     // 该阶段喂养要点
    let foods: [BabyFood]
}

enum BabyFoodLibrary {
    static let stages: [FoodStage] = [
        FoodStage(id: 0, label: "6-7 月龄", subtitle: "初尝辅食 · 细腻泥糊", feeding: "第一口辅食首选富含铁的食物。每天 1 次辅食，先吃辅食再喝奶；由稀到稠、由少到多（1-2 勺起步），每次只加一种新食物，观察 2-3 天有无皮疹、呕吐、腹泻。奶量仍保持 600-800ml/天。", foods: [
            BabyFood(name: "强化铁米粉", img: "iron_cereal", benefit: "强化了铁，正好补上 6 个月后宝宝体内储备铁的下降，预防缺铁性贫血；质地细腻好消化，是最稳妥的第一口辅食。", bestTime: "上午加餐时段（约 10:00），安排在两次奶之间", steps: [
                "洗净双手和餐具，取 1-2 勺强化铁米粉倒入小碗",
                "倒入约 40℃ 的温奶或温水，边倒边搅拌",
                "调成酸奶般能缓慢流动的稀糊，静置 1 分钟吸足水分",
                "用软勺舀少量喂给宝宝，适应 3-5 天后再逐渐加量、调稠",
            ], note: "选「婴幼儿强化铁」米粉，自家磨的米糊铁不够，不能替代。"),
            BabyFood(name: "猪肉泥 / 牛肉泥", img: "meat_puree", benefit: "红肉是血红素铁和锌的最佳来源，吸收率高，是预防贫血的主力；蛋白质支持生长发育。", bestTime: "午餐时段（约 11:30-12:00），拌入米粉或粥里", steps: [
                "里脊肉去筋膜、切小块，冷水下锅",
                "撇去浮沫后中火煮 15 分钟至完全熟透",
                "加少量温水放入料理机，打成无明显颗粒的细泥",
                "拌入米粉或粥里喂，第一次只给 1-2 小勺",
            ], note: "初期要打成无明显颗粒的细泥。"),
            BabyFood(name: "南瓜泥", img: "pumpkin_puree", benefit: "β-胡萝卜素在体内转化为维生素 A，护眼护皮肤、增强抵抗力；口味清甜宝宝容易接受。", bestTime: "上午或中午辅食时段，可单独吃也可拌米粉", steps: [
                "南瓜去皮去瓤，切成 2cm 左右的小块",
                "冷水上锅蒸 12-15 分钟，至筷子能轻松扎透",
                "趁热压成泥并过筛，口感更细腻",
                "太稠时加温水或奶调稀即可",
            ]),
            BabyFood(name: "西兰花泥", img: "broccoli_puree", benefit: "维生素 C 促进铁吸收，叶酸和膳食纤维帮助肠道发育。", bestTime: "上午或中午辅食时段，与米粉同喂更好接受", steps: [
                "西兰花切小朵，淡盐水浸泡 10 分钟后冲洗干净",
                "水开下锅煮 5-6 分钟，至花蕾软烂",
                "取花蕾部分加少量温水打泥（茎部纤维粗可弃用）",
                "可与米粉或土豆泥混合，减轻青草味",
            ]),
            BabyFood(name: "苹果泥", img: "apple_puree", benefit: "果胶（膳食纤维）温和调理肠道；生苹果泥偏通便，蒸熟的偏收敛止泻。", bestTime: "上午辅食时段；腹泻期选蒸熟苹果泥更合适", steps: [
                "苹果去皮去核，切成小块",
                "上锅蒸 8-10 分钟，至叉子轻压即碎",
                "用研磨碗压成细泥，颗粒大的部分过筛",
                "小月龄建议蒸熟再给，更温和不刺激肠胃",
            ]),
            BabyFood(name: "土豆泥", img: "potato_puree", benefit: "碳水化合物提供能量，性质温和、不易胀气不易过敏，适合做蔬菜类打底。", bestTime: "中午辅食时段，可代替米粉做一餐主食打底", steps: [
                "土豆去皮切 2cm 块，清水冲去表面淀粉",
                "蒸 15 分钟，至筷子能扎透",
                "趁热压泥（放凉会发黏难压），加温水或奶调成细滑糊",
                "可混入菜泥、肉泥，营养更全面",
            ]),
            BabyFood(name: "蛋黄（7 月龄起）", img: "egg_yolk", benefit: "含铁、卵磷脂和胆碱，对大脑和神经系统发育很重要。", bestTime: "上午辅食时段，拌入米粉或粥里，便于观察反应", steps: [
                "鸡蛋冷水下锅，水开后煮 8-10 分钟至全熟",
                "捞出过凉水剥壳，取出蛋黄",
                "取 1/4 个蛋黄压碎，用奶、米粉或粥调成糊",
                "连续观察 3 天无皮疹呕吐，再逐步加到半个、整个",
            ], note: "每次加量后观察 3 天，无皮疹呕吐再逐步加到半个、整个。"),
        ]),
        FoodStage(id: 1, label: "7-9 月龄", subtitle: "蠕嚼期 · 碎末与手指食物", feeding: "每天 1-2 次辅食，从细泥过渡到稍粗的碎末状，让宝宝练习蠕嚼；可以给蒸软的手指食物让他自己抓着吃。奶量保持 600ml 左右。", foods: [
            BabyFood(name: "猪肝泥 / 鸡肝泥", img: "liver_puree", benefit: "铁和维生素 A 密度很高，是轻度贫血宝宝的首选食材。", bestTime: "中午辅食时段，每周 1-2 次，拌入粥或面里", steps: [
                "猪肝切薄片，清水浸泡 30 分钟并换水 2 次，去净血水",
                "冷水下锅煮 10 分钟，至内部完全变色",
                "加少量温水打成细泥，分成小份冷冻保存",
                "每次取一小份加热后，拌入粥或面里喂",
            ], note: "每周 1-2 次即可，维生素 A 过量反而不好。"),
            BabyFood(name: "三文鱼泥 / 鳕鱼泥", img: "fish_puree", benefit: "DHA 助力大脑和视网膜发育，肉质软嫩、刺少。", bestTime: "中午辅食时段；第一次安排在上午，便于观察过敏", steps: [
                "鱼块冲洗后放盘中，水开上锅蒸 8-10 分钟",
                "蒸好后仔细挑净小刺，去掉鱼皮",
                "用勺压成泥，或剁成小碎末",
                "拌进粥或烂面条里，第一次只给一小勺观察过敏",
            ], note: "第一次吃先给一小勺观察过敏反应。"),
            BabyFood(name: "内酯豆腐", img: "silken_tofu", benefit: "优质植物蛋白和钙，质地嫩滑几乎不用嚼，过敏风险低。", bestTime: "中午或晚餐辅食时段，直接拌入粥、面", steps: [
                "内酯豆腐切成小块",
                "沸水焯 1 分钟，去除豆腥味",
                "沥水后用勺背压碎",
                "直接拌入粥、烂面里喂，也可加一点肉泥提味",
            ], note: "选内酯豆腐/嫩豆腐，老豆腐偏硬不适合。"),
            BabyFood(name: "全蛋蒸蛋羹", img: "steamed_egg", benefit: "9 月龄左右可以尝试全蛋；蛋白质和卵磷脂丰富，蒸蛋嫩滑易吞咽。", bestTime: "上午或中午辅食时段，可当一顿完整辅食", steps: [
                "1 个全蛋打入碗中，加 1.5 倍约 40℃ 温水打匀",
                "过筛去掉泡沫，蒸出来更嫩滑",
                "盖保鲜膜扎几个小孔，水开后中小火蒸 10 分钟",
                "出锅放温即可喂，可滴两滴香油提香（可选）",
            ], note: "确诊鸡蛋过敏的宝宝推迟添加并咨询医生。"),
            BabyFood(name: "烂面条", img: "soft_noodle", benefit: "从糊状过渡到软烂颗粒，锻炼咀嚼和吞咽节奏，碳水供能扎实。", bestTime: "中午辅食时段，可做一顿主食", steps: [
                "婴儿面条掰成小段",
                "水开下锅，煮至比包装建议再多 2-3 分钟的软烂度",
                "加入菜末、肝泥或蛋黄碎，再同煮 2 分钟",
                "出锅可不加调味，或只加一点婴儿酱油",
            ]),
            BabyFood(name: "香蕉 / 牛油果压泥", img: "banana_avocado", benefit: "牛油果富含不饱和脂肪酸（好脂肪）帮助大脑发育，香蕉补钾、润肠通便；两者能量密度高。", bestTime: "上午加餐，或正餐后的水果时段", steps: [
                "选熟透的香蕉（皮带黑斑），剥皮用勺压成粗泥",
                "牛油果对半切开去核，取果肉压泥",
                "太稠可混少量奶或米粉调稀",
                "现吃现做，氧化变色后就不要再喂了",
            ]),
            BabyFood(name: "手指食物（蒸胡萝卜条）", img: "carrot_sticks", benefit: "锻炼捏握能力和自主进食意识，熟悉不同食物质地，为咀嚼打基础。", bestTime: "上午或下午加餐时段，正好练抓握", steps: [
                "胡萝卜去皮，切成小指粗、约 6cm 的长条",
                "冷水上锅蒸 10-12 分钟，到「软而不断」",
                "放温至不烫手，摆上餐盘",
                "让宝宝自己抓着啃，大人全程在旁看护",
            ], note: "吃的时候大人必须在旁边看护。"),
        ]),
        FoodStage(id: 2, label: "10-12 月龄", subtitle: "咀嚼期 · 软小块", feeding: "每天 2-3 次辅食，性状从碎末过渡到软小块（约香蕉硬度），鼓励自己抓吃；奶量 500-600ml。整颗坚果、果冻、整粒葡萄等呛噎风险食物一定不要给。", foods: [
            BabyFood(name: "软米饭 / 稠粥", img: "soft_rice", benefit: "主食升级，练习用牙龈咀嚼软块，为接受家庭餐做准备。", bestTime: "午餐或晚餐的主食时段", steps: [
                "大米淘洗后，按米水比约 1:2.5 加水",
                "大火煮开转小火焖煮 25-30 分钟，成软饭或稠粥",
                "配上肉末、碎菜拌匀一起吃",
                "稍放温后再给，鼓励宝宝自己抓小饭团",
            ]),
            BabyFood(name: "虾仁碎 / 小虾丸", img: "shrimp_ball", benefit: "优质蛋白 + 锌 + 钙，脂肪低；锌帮助味觉发育、改善食欲。", bestTime: "中午辅食时段；第一次先给少量观察过敏", steps: [
                "鲜虾去头壳、挑净虾线，洗净吸干水分",
                "煮熟后剁碎，或加蛋清搅打成虾泥",
                "做虾丸：虾泥顺一个方向搅打上劲，搓成小丸",
                "小火煮至浮起再煮 2 分钟，确保熟透",
            ], note: "虾是常见过敏原，第一次只给少量。"),
            BabyFood(name: "小馄饨 / 小饺子", img: "mini_wonton", benefit: "一张皮包进肉、菜、蛋多种食材，营养密度高，形状有趣宝宝更爱吃。", bestTime: "午餐或晚餐，一次 5-8 个", steps: [
                "猪肉末 + 碎菜 + 少许蛋清，顺一个方向拌匀成馅",
                "馄饨皮切四小片，包成迷你馄饨（可多做些冷冻保存）",
                "水开下锅，煮至浮起后再煮 2 分钟",
                "确保皮软烂、馅熟透，连汤放温再喂",
            ]),
            BabyFood(name: "肉末豆腐羹", img: "tofu_soup", benefit: "动植物蛋白互补、钙丰富，羹状质地好嚼好咽，适合刚长几颗牙的宝宝。", bestTime: "午餐或晚餐，配软饭一起吃", steps: [
                "肉末用少量油炒香，加水煮开",
                "下嫩豆腐碎，中小火煮 3 分钟",
                "水淀粉勾薄芡，让羹变浓稠好入口",
                "关火前撒碎青菜，烫熟即可",
            ]),
            BabyFood(name: "无糖原味酸奶", img: "yogurt", benefit: "牛奶蛋白经发酵更好消化，钙和益生菌有益肠道健康，是很好的加餐。", bestTime: "下午加餐时段（约 15:00），或早餐配主食", steps: [
                "挑配料表只有「生牛乳 + 菌种」的无糖酸奶",
                "从冰箱取出放至不冰凉再给（室温回温约 10 分钟）",
                "直接吃，或拌入水果泥增加风味",
                "开封后一次吃完，剩下不再喂",
            ], note: "1 岁前牛奶不能当主饮品，但酸奶作辅食是可以的。"),
            BabyFood(name: "紫菜虾皮粉", img: "seaweed_powder", benefit: "天然「补钙小帮手」，紫菜还含碘，帮助甲状腺功能和大脑发育。", bestTime: "随餐调味，拌进粥、面里即可，无固定时段", steps: [
                "无盐虾皮清水冲洗沥干，紫菜撕成小块",
                "干锅小火烘 3-5 分钟至酥脆，勤翻动防糊",
                "放凉后用料理机打成细粉",
                "装入密封罐冷藏，每次 1 小勺撒进粥、面里",
            ], note: "务必选无盐虾皮，成人虾皮钠太高。"),
            BabyFood(name: "蔬菜蛋饼", img: "veggie_pancake", benefit: "蛋、菜、主食一张饼全搞定，切成小条还能练自主进食。", bestTime: "早餐，或下午加餐当手指食物", steps: [
                "鸡蛋 + 面粉 + 碎菜 + 少量水，调成酸奶状的糊",
                "平底锅刷薄油，最小火倒入面糊摊圆",
                "一面凝固后翻面，煎至两面微黄熟透",
                "切成小条放凉一点再给，防烫口",
            ]),
        ]),
        FoodStage(id: 3, label: "1-2 岁", subtitle: "学步期 · 家庭餐过渡", feeding: "一日三餐 + 2 次加餐，和大人同桌吃少盐少糖的家常菜，性状为小块软饭；每天奶量 400-600ml，继续每天补维生素 D。让宝宝自己拿勺，吃得脏一点没关系。", foods: [
            BabyFood(name: "二米粥 / 杂粮软饭", img: "mixed_congee", benefit: "大米配小米或燕麦，B 族维生素和膳食纤维更丰富，肠道更通畅。", bestTime: "早餐或晚餐的主食时段", steps: [
                "小米和大米按 1:1 淘洗干净",
                "加 6-8 倍水，大火煮开转小火熬 30 分钟成稠粥",
                "配肉末和碎菜一起吃，营养更均衡",
                "也可用电饭煲杂粮饭模式做软饭",
            ]),
            BabyFood(name: "清蒸鱼块", img: "steamed_fish", benefit: "DHA 和优质蛋白持续供应大脑发育，每周吃鱼 2-3 次为宜。", bestTime: "午餐时段，每周 2-3 次", steps: [
                "鳕鱼 / 鲈鱼段冲洗，摆盘铺两片姜去腥",
                "水开上锅蒸 8-10 分钟",
                "出锅后仔细挑净鱼刺、去掉鱼皮",
                "压成小块直接吃，1 岁后也可不调味",
            ], note: "吃鱼时务必再检查一遍小刺。"),
            BabyFood(name: "番茄炖牛腩", img: "tomato_beef", benefit: "番茄的维生素 C 促进牛肉里铁的吸收，酸甜开胃；炖到软烂好嚼不塞牙。", bestTime: "午餐时段（炖煮时间长，适合周末多做）", steps: [
                "牛腩切小块冷水下锅焯水，撇净浮沫",
                "番茄去皮切块，小火炒出汁",
                "加牛腩和热水，小火炖 60-90 分钟至软烂",
                "剪成小丁连汤拌饭，不加盐或少盐",
            ]),
            BabyFood(name: "时蔬鸡蛋小饼", img: "veggie_bites", benefit: "蛋白质、碳水、蔬菜一饼俱全，切条后自己抓着吃，锻炼咀嚼和手眼协调。", bestTime: "早餐，或下午加餐", steps: [
                "鸡蛋 + 面粉 + 西葫芦 / 胡萝卜碎，调成稠酸奶状糊",
                "平底锅刷薄油，小火摊成小圆饼",
                "每面煎 2-3 分钟，至熟透微黄",
                "切成小条放温再给",
            ]),
            BabyFood(name: "奶酪 / 奶制品加餐", img: "cheese", benefit: "浓缩的钙和蛋白质，是长骨骼和牙齿的主力加餐。", bestTime: "上午或下午加餐，每天 1-2 小块", steps: [
                "选婴儿奶酪或低钠原味奶酪（钠越低越好）",
                "切成 1cm 小块，放至室温再给",
                "也可用无糖酸奶拌水果块替换",
                "吃完喝几口水，防奶酪渣粘牙",
            ], note: "选钠含量低的品种，每天 1-2 小块即可。"),
            BabyFood(name: "水果块", img: "fruit_cubes", benefit: "直接啃水果块锻炼咀嚼，补充维生素 C 和膳食纤维；整果永远比果汁好。", bestTime: "上午或下午加餐、正餐后的水果时段", steps: [
                "香蕉、草莓、火龙果等软果去皮，切 1cm 小块",
                "苹果等硬果先蒸 5 分钟蒸软再切",
                "整颗葡萄、圣女果必须切四瓣",
                "大人在旁看着吃，坐好吃、不跑跳",
            ], note: "圆滑硬质水果（整颗葡萄、圣女果）要切四瓣防呛噎。"),
            BabyFood(name: "豆腐蔬菜丸子", img: "tofu_balls", benefit: "植物蛋白+蔬菜混搭，营养密度高，丸子形状让宝宝更愿意吃蔬菜。", bestTime: "午餐或晚餐，配主食一起", steps: [
                "老豆腐压碎，挤干水分",
                "加胡萝卜碎、少许淀粉和蛋清，顺一个方向拌匀",
                "搓成鹌鹑蛋大小的丸子",
                "水开上锅蒸 12 分钟，或小火煮熟即可",
            ]),
        ]),
        FoodStage(id: 4, label: "2-3 岁", subtitle: "幼儿期 · 三餐两点", feeding: "和全家吃一样的三餐 + 两点，只是少盐少糖、食材切小块；每天奶量 350-500ml。固定餐位、不追喂不哄喂，鼓励自己吃完一整餐。", foods: [
            BabyFood(name: "全麦小馒头 / 发糕", img: "steamed_bun", benefit: "全谷的膳食纤维预防便秘，B 族维生素丰富；发糕松软好嚼，接受度高。", bestTime: "早餐主食，或下午加餐", steps: [
                "面粉 + 奶粉 + 酵母 + 温水，揉成光滑面团",
                "盖保鲜膜发酵至 1.5 倍大（约 40 分钟）",
                "揉面排气后做形，可掺南瓜泥、红枣碎",
                "冷水上锅，水开后蒸 15 分钟，关火焖 3 分钟再开盖",
            ]),
            BabyFood(name: "时蔬蛋炒饭", img: "fried_rice", benefit: "一碗里同时有主食、蛋和多种蔬菜，色彩丰富，是对付挑食的好办法。", bestTime: "午餐或晚餐的主食时段", steps: [
                "胡萝卜、玉米、豌豆提前煮软",
                "鸡蛋炒散，盛出备用",
                "少油下软米饭炒散，加入蔬菜丁和鸡蛋",
                "小火炒软炒透，盐控制在 1g 以内或用香菇提鲜",
            ]),
            BabyFood(name: "清蒸鱼 / 白灼虾", img: "fish_shrimp", benefit: "DHA、碘、锌持续供应大脑与体格发育，每周水产 2-3 次。", bestTime: "午餐或晚餐，每周水产 2-3 次", steps: [
                "龙利鱼 / 鲈鱼段铺姜片，水开蒸 8 分钟",
                "鲜虾水开下锅白灼 3-4 分钟，至变红卷曲",
                "虾去壳切段，鱼挑净刺",
                "都不需要重调味，可挤两滴柠檬汁去腥",
            ]),
            BabyFood(name: "小米南瓜粥", img: "millet_pumpkin", benefit: "养胃好消化，β-胡萝卜素+膳食纤维双补，肠胃不舒服或腹泻恢复期也很友好。", bestTime: "早餐或晚餐主食，肠胃不适时也适合", steps: [
                "小米淘洗，南瓜去皮切小块",
                "一起下锅加 8 倍水，大火煮开",
                "转小火煮 30 分钟至软糯，中途搅两次防粘底",
                "熬到南瓜化在粥里，最香甜",
            ]),
            BabyFood(name: "水果酸奶杯", img: "yogurt_cup", benefit: "加餐界的营养优等生：蛋白质、钙、益生菌、维生素 C 一次到位。", bestTime: "下午加餐时段（约 15:00）", steps: [
                "无糖酸奶倒入小杯，铺一层",
                "加一层切碎的时令水果",
                "再撒一小勺即食燕麦片，层层叠加",
                "做好马上吃，放久了燕麦会泡软",
            ]),
            BabyFood(name: "迷你鸡肉蔬菜丸", img: "chicken_balls", benefit: "肉菜混搭营养密度高，自己捏着吃还能练精细动作。", bestTime: "午餐或晚餐配菜，也方便当加餐带出门", steps: [
                "鸡肉末 + 胡萝卜碎 + 少许淀粉，顺一个方向搅打上劲",
                "搓成直径约 2cm 的迷你丸子",
                "水微开下锅煮 6-8 分钟，全部浮起即熟",
                "也可上锅蒸 12 分钟，一次多做些冷冻保存",
            ]),
            BabyFood(name: "无糖豆浆 / 豆腐脑", img: "soy_milk", benefit: "植物蛋白和钙的好来源，乳糖不耐受宝宝的替代选择。", bestTime: "早餐时段，配主食一起", steps: [
                "干黄豆泡发 8 小时以上，加水打成豆浆",
                "必须彻底煮沸后再继续煮 5 分钟以上（防皂苷引起恶心呕吐）",
                "放温至不烫口再给",
                "也可买现成无糖豆腐脑，直接当早餐",
            ]),
        ]),
    ]

    /// 根据月龄返回默认选中的阶段 id（未满 6 月也落在第一阶段）
    static func stageIndex(forMonths m: Int) -> Int {
        switch m {
        case ..<8: return 0
        case 8...9: return 1
        case 10...12: return 2
        case 13...24: return 3
        default: return 4
        }
    }
}

// MARK: - 辅食推荐页

struct BabyFoodView: View {
    let child: Child?
    @State private var stageId: Int = 0
    @State private var expanded: String? = nil

    private var stage: FoodStage { BabyFoodLibrary.stages[stageId] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 月龄段选择
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(BabyFoodLibrary.stages) { s in
                            let active = s.id == stageId
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    stageId = s.id
                                    expanded = nil
                                }
                            } label: {
                                Text(s.label)
                                    .font(.system(size: 13, weight: active ? .semibold : .regular))
                                    .foregroundColor(active ? .white : Palette.ink)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(active ? Palette.purple : Palette.card)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(active ? Color.clear : Palette.hairline, lineWidth: 1))
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // 阶段说明卡
                VStack(alignment: .leading, spacing: 6) {
                    Text(stage.subtitle).font(.system(size: 15, weight: .semibold)).foregroundColor(Palette.ink)
                    Text(stage.feeding)
                        .font(.system(size: 12.5))
                        .foregroundColor(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 14)
                .padding(.horizontal, 16)

                // 辅食列表
                VStack(spacing: 0) {
                    ForEach(stage.foods) { food in
                        FoodRow(
                            food: food,
                            expanded: expanded == food.id,
                            onTap: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    expanded = expanded == food.id ? nil : food.id
                                }
                            }
                        )
                        if food.id != stage.foods.last?.id {
                            Divider().background(Palette.hairlineSoft)
                        }
                    }
                }
                .cardStyle(padding: 0)
                .padding(.horizontal, 16)

                Text("内容根据国家卫健委婴幼儿喂养科普与儿保常识整理，仅供参考；宝宝生病、过敏或生长发育异常时，请遵医嘱调整。")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
            .padding(.top, 12)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("辅食推荐")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let child = child {
                let m = GrowthMath.ageMonths(from: child.birthDate)
                stageId = BabyFoodLibrary.stageIndex(forMonths: m)
            }
        }
    }
}

private struct FoodRow: View {
    let food: BabyFood
    let expanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 11) {
                    // 食材图片
                    Image(food.img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 46, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(food.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.ink)
                        Text(expanded ? food.benefit : String(food.benefit.prefix(24)) + (food.benefit.count > 24 ? "…" : ""))
                            .font(.system(size: 11.5))
                            .foregroundColor(Palette.subtle)
                            .lineLimit(expanded ? nil : 1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Palette.subtle)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    // 大图
                    Image(food.img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // 建议时段
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "clock.fill").font(.system(size: 11))
                        Text(food.bestTime).font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundColor(Palette.purple)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.purple.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                    Label("对宝宝的好处", systemImage: "heart.fill")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(Palette.purple)
                    Text(food.benefit)
                        .font(.system(size: 12.5)).foregroundColor(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true).lineSpacing(3)

                    Label("烹饪步骤", systemImage: "fork.knife")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(Palette.purple)
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(Array(food.steps.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(i + 1)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Circle().fill(Palette.purple.opacity(0.85)))
                                Text(step)
                                    .font(.system(size: 12.5)).foregroundColor(Palette.ink2)
                                    .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                            }
                        }
                    }

                    if let note = food.note {
                        HStack(alignment: .top, spacing: 5) {
                            Image(systemName: "exclamationmark.circle.fill").font(.system(size: 11))
                            Text(note).font(.system(size: 11.5))
                        }
                        .foregroundColor(Palette.warn)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.warnBg)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 13)
            }
        }
    }
}
