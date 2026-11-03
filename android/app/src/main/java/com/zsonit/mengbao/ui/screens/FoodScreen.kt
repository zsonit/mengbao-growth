package com.zsonit.mengbao.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zsonit.mengbao.R
import com.zsonit.mengbao.data.GrowthMath
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.ui.*

// MARK: 辅食数据

data class BabyFood(
    val name: String,
    val img: String,          // 食材图片 drawable 名
    val benefit: String,      // 对宝宝的作用 / 健康好处
    val bestTime: String,     // 建议食用时段
    val steps: List<String>,  // 烹饪步骤
    val note: String? = null, // 小提示
)

data class FoodStage(
    val label: String,     // "6-7 月龄"
    val subtitle: String,  // 阶段特点
    val feeding: String,   // 喂养要点
    val foods: List<BabyFood>,
)

object BabyFoodLibrary {

    /** 根据月龄返回默认选中的阶段下标（未满 6 月也落在第一阶段） */
    fun stageIndex(months: Int): Int = when {
        months < 8 -> 0
        months <= 9 -> 1
        months <= 12 -> 2
        months <= 24 -> 3
        else -> 4
    }

    val stages = listOf(
        FoodStage(
            "6-7 月龄", "初尝辅食 · 细腻泥糊",
            "第一口辅食首选富含铁的食物。每天 1 次辅食，先吃辅食再喝奶；由稀到稠、由少到多（1-2 勺起步），每次只加一种新食物，观察 2-3 天有无皮疹、呕吐、腹泻。奶量仍保持 600-800ml/天。",
            listOf(
                BabyFood("强化铁米粉", "iron_cereal", "强化了铁，正好补上 6 个月后宝宝体内储备铁的下降，预防缺铁性贫血；质地细腻好消化，是最稳妥的第一口辅食。", "上午加餐时段（约 10:00），安排在两次奶之间", listOf(
                    "洗净双手和餐具，取 1-2 勺强化铁米粉倒入小碗",
                    "倒入约 40℃ 的温奶或温水，边倒边搅拌",
                    "调成酸奶般能缓慢流动的稀糊，静置 1 分钟吸足水分",
                    "用软勺舀少量喂给宝宝，适应 3-5 天后再逐渐加量、调稠",
                ), "选「婴幼儿强化铁」米粉，自家磨的米糊铁不够，不能替代。"),
                BabyFood("猪肉泥 / 牛肉泥", "meat_puree", "红肉是血红素铁和锌的最佳来源，吸收率高，是预防贫血的主力；蛋白质支持生长发育。", "午餐时段（约 11:30-12:00），拌入米粉或粥里", listOf(
                    "里脊肉去筋膜、切小块，冷水下锅",
                    "撇去浮沫后中火煮 15 分钟至完全熟透",
                    "加少量温水放入料理机，打成无明显颗粒的细泥",
                    "拌入米粉或粥里喂，第一次只给 1-2 小勺",
                ), "初期要打成无明显颗粒的细泥。"),
                BabyFood("南瓜泥", "pumpkin_puree", "β-胡萝卜素在体内转化为维生素 A，护眼护皮肤、增强抵抗力；口味清甜宝宝容易接受。", "上午或中午辅食时段，可单独吃也可拌米粉", listOf(
                    "南瓜去皮去瓤，切成 2cm 左右的小块",
                    "冷水上锅蒸 12-15 分钟，至筷子能轻松扎透",
                    "趁热压成泥并过筛，口感更细腻",
                    "太稠时加温水或奶调稀即可",
                )),
                BabyFood("西兰花泥", "broccoli_puree", "维生素 C 促进铁吸收，叶酸和膳食纤维帮助肠道发育。", "上午或中午辅食时段，与米粉同喂更好接受", listOf(
                    "西兰花切小朵，淡盐水浸泡 10 分钟后冲洗干净",
                    "水开下锅煮 5-6 分钟，至花蕾软烂",
                    "取花蕾部分加少量温水打泥（茎部纤维粗可弃用）",
                    "可与米粉或土豆泥混合，减轻青草味",
                )),
                BabyFood("苹果泥", "apple_puree", "果胶（膳食纤维）温和调理肠道；生苹果泥偏通便，蒸熟的偏收敛止泻。", "上午辅食时段；腹泻期选蒸熟苹果泥更合适", listOf(
                    "苹果去皮去核，切成小块",
                    "上锅蒸 8-10 分钟，至叉子轻压即碎",
                    "用研磨碗压成细泥，颗粒大的部分过筛",
                    "小月龄建议蒸熟再给，更温和不刺激肠胃",
                )),
                BabyFood("土豆泥", "potato_puree", "碳水化合物提供能量，性质温和、不易胀气不易过敏，适合做蔬菜类打底。", "中午辅食时段，可代替米粉做一餐主食打底", listOf(
                    "土豆去皮切 2cm 块，清水冲去表面淀粉",
                    "蒸 15 分钟，至筷子能扎透",
                    "趁热压泥（放凉会发黏难压），加温水或奶调成细滑糊",
                    "可混入菜泥、肉泥，营养更全面",
                )),
                BabyFood("蛋黄（7 月龄起）", "egg_yolk", "含铁、卵磷脂和胆碱，对大脑和神经系统发育很重要。", "上午辅食时段，拌入米粉或粥里，便于观察反应", listOf(
                    "鸡蛋冷水下锅，水开后煮 8-10 分钟至全熟",
                    "捞出过凉水剥壳，取出蛋黄",
                    "取 1/4 个蛋黄压碎，用奶、米粉或粥调成糊",
                    "连续观察 3 天无皮疹呕吐，再逐步加到半个、整个",
                ), "每次加量后观察 3 天，无皮疹呕吐再逐步加到半个、整个。"),
            ),
        ),
        FoodStage(
            "7-9 月龄", "蠕嚼期 · 碎末与手指食物",
            "每天 1-2 次辅食，从细泥过渡到稍粗的碎末状，让宝宝练习蠕嚼；可以给蒸软的手指食物让他自己抓着吃。奶量保持 600ml 左右。",
            listOf(
                BabyFood("猪肝泥 / 鸡肝泥", "liver_puree", "铁和维生素 A 密度很高，是轻度贫血宝宝的首选食材。", "中午辅食时段，每周 1-2 次，拌入粥或面里", listOf(
                    "猪肝切薄片，清水浸泡 30 分钟并换水 2 次，去净血水",
                    "冷水下锅煮 10 分钟，至内部完全变色",
                    "加少量温水打成细泥，分成小份冷冻保存",
                    "每次取一小份加热后，拌入粥或面里喂",
                ), "每周 1-2 次即可，维生素 A 过量反而不好。"),
                BabyFood("三文鱼泥 / 鳕鱼泥", "fish_puree", "DHA 助力大脑和视网膜发育，肉质软嫩、刺少。", "中午辅食时段；第一次安排在上午，便于观察过敏", listOf(
                    "鱼块冲洗后放盘中，水开上锅蒸 8-10 分钟",
                    "蒸好后仔细挑净小刺，去掉鱼皮",
                    "用勺压成泥，或剁成小碎末",
                    "拌进粥或烂面条里，第一次只给一小勺观察过敏",
                ), "第一次吃先给一小勺观察过敏反应。"),
                BabyFood("内酯豆腐", "silken_tofu", "优质植物蛋白和钙，质地嫩滑几乎不用嚼，过敏风险低。", "中午或晚餐辅食时段，直接拌入粥、面", listOf(
                    "内酯豆腐切成小块",
                    "沸水焯 1 分钟，去除豆腥味",
                    "沥水后用勺背压碎",
                    "直接拌入粥、烂面里喂，也可加一点肉泥提味",
                ), "选内酯豆腐/嫩豆腐，老豆腐偏硬不适合。"),
                BabyFood("全蛋蒸蛋羹", "steamed_egg", "9 月龄左右可以尝试全蛋；蛋白质和卵磷脂丰富，蒸蛋嫩滑易吞咽。", "上午或中午辅食时段，可当一顿完整辅食", listOf(
                    "1 个全蛋打入碗中，加 1.5 倍约 40℃ 温水打匀",
                    "过筛去掉泡沫，蒸出来更嫩滑",
                    "盖保鲜膜扎几个小孔，水开后中小火蒸 10 分钟",
                    "出锅放温即可喂，可滴两滴香油提香（可选）",
                ), "确诊鸡蛋过敏的宝宝推迟添加并咨询医生。"),
                BabyFood("烂面条", "soft_noodle", "从糊状过渡到软烂颗粒，锻炼咀嚼和吞咽节奏，碳水供能扎实。", "中午辅食时段，可做一顿主食", listOf(
                    "婴儿面条掰成小段",
                    "水开下锅，煮至比包装建议再多 2-3 分钟的软烂度",
                    "加入菜末、肝泥或蛋黄碎，再同煮 2 分钟",
                    "出锅可不加调味，或只加一点婴儿酱油",
                )),
                BabyFood("香蕉 / 牛油果压泥", "banana_avocado", "牛油果富含不饱和脂肪酸（好脂肪）帮助大脑发育，香蕉补钾、润肠通便；两者能量密度高。", "上午加餐，或正餐后的水果时段", listOf(
                    "选熟透的香蕉（皮带黑斑），剥皮用勺压成粗泥",
                    "牛油果对半切开去核，取果肉压泥",
                    "太稠可混少量奶或米粉调稀",
                    "现吃现做，氧化变色后就不要再喂了",
                )),
                BabyFood("手指食物（蒸胡萝卜条）", "carrot_sticks", "锻炼捏握能力和自主进食意识，熟悉不同食物质地，为咀嚼打基础。", "上午或下午加餐时段，正好练抓握", listOf(
                    "胡萝卜去皮，切成小指粗、约 6cm 的长条",
                    "冷水上锅蒸 10-12 分钟，到「软而不断」",
                    "放温至不烫手，摆上餐盘",
                    "让宝宝自己抓着啃，大人全程在旁看护",
                ), "吃的时候大人必须在旁边看护。"),
            ),
        ),
        FoodStage(
            "10-12 月龄", "咀嚼期 · 软小块",
            "每天 2-3 次辅食，性状从碎末过渡到软小块（约香蕉硬度），鼓励自己抓吃；奶量 500-600ml。整颗坚果、果冻、整粒葡萄等呛噎风险食物一定不要给。",
            listOf(
                BabyFood("软米饭 / 稠粥", "soft_rice", "主食升级，练习用牙龈咀嚼软块，为接受家庭餐做准备。", "午餐或晚餐的主食时段", listOf(
                    "大米淘洗后，按米水比约 1:2.5 加水",
                    "大火煮开转小火焖煮 25-30 分钟，成软饭或稠粥",
                    "配上肉末、碎菜拌匀一起吃",
                    "稍放温后再给，鼓励宝宝自己抓小饭团",
                )),
                BabyFood("虾仁碎 / 小虾丸", "shrimp_ball", "优质蛋白 + 锌 + 钙，脂肪低；锌帮助味觉发育、改善食欲。", "中午辅食时段；第一次先给少量观察过敏", listOf(
                    "鲜虾去头壳、挑净虾线，洗净吸干水分",
                    "煮熟后剁碎，或加蛋清搅打成虾泥",
                    "做虾丸：虾泥顺一个方向搅打上劲，搓成小丸",
                    "小火煮至浮起再煮 2 分钟，确保熟透",
                ), "虾是常见过敏原，第一次只给少量。"),
                BabyFood("小馄饨 / 小饺子", "mini_wonton", "一张皮包进肉、菜、蛋多种食材，营养密度高，形状有趣宝宝更爱吃。", "午餐或晚餐，一次 5-8 个", listOf(
                    "猪肉末 + 碎菜 + 少许蛋清，顺一个方向拌匀成馅",
                    "馄饨皮切四小片，包成迷你馄饨（可多做些冷冻保存）",
                    "水开下锅，煮至浮起后再煮 2 分钟",
                    "确保皮软烂、馅熟透，连汤放温再喂",
                )),
                BabyFood("肉末豆腐羹", "tofu_soup", "动植物蛋白互补、钙丰富，羹状质地好嚼好咽，适合刚长几颗牙的宝宝。", "午餐或晚餐，配软饭一起吃", listOf(
                    "肉末用少量油炒香，加水煮开",
                    "下嫩豆腐碎，中小火煮 3 分钟",
                    "水淀粉勾薄芡，让羹变浓稠好入口",
                    "关火前撒碎青菜，烫熟即可",
                )),
                BabyFood("无糖原味酸奶", "yogurt", "牛奶蛋白经发酵更好消化，钙和益生菌有益肠道健康，是很好的加餐。", "下午加餐时段（约 15:00），或早餐配主食", listOf(
                    "挑配料表只有「生牛乳 + 菌种」的无糖酸奶",
                    "从冰箱取出放至不冰凉再给（室温回温约 10 分钟）",
                    "直接吃，或拌入水果泥增加风味",
                    "开封后一次吃完，剩下不再喂",
                ), "1 岁前牛奶不能当主饮品，但酸奶作辅食是可以的。"),
                BabyFood("紫菜虾皮粉", "seaweed_powder", "天然「补钙小帮手」，紫菜还含碘，帮助甲状腺功能和大脑发育。", "随餐调味，拌进粥、面里即可，无固定时段", listOf(
                    "无盐虾皮清水冲洗沥干，紫菜撕成小块",
                    "干锅小火烘 3-5 分钟至酥脆，勤翻动防糊",
                    "放凉后用料理机打成细粉",
                    "装入密封罐冷藏，每次 1 小勺撒进粥、面里",
                ), "务必选无盐虾皮，成人虾皮钠太高。"),
                BabyFood("蔬菜蛋饼", "veggie_pancake", "蛋、菜、主食一张饼全搞定，切成小条还能练自主进食。", "早餐，或下午加餐当手指食物", listOf(
                    "鸡蛋 + 面粉 + 碎菜 + 少量水，调成酸奶状的糊",
                    "平底锅刷薄油，最小火倒入面糊摊圆",
                    "一面凝固后翻面，煎至两面微黄熟透",
                    "切成小条放凉一点再给，防烫口",
                )),
            ),
        ),
        FoodStage(
            "1-2 岁", "学步期 · 家庭餐过渡",
            "一日三餐 + 2 次加餐，和大人同桌吃少盐少糖的家常菜，性状为小块软饭；每天奶量 400-600ml，继续每天补维生素 D。让宝宝自己拿勺，吃得脏一点没关系。",
            listOf(
                BabyFood("二米粥 / 杂粮软饭", "mixed_congee", "大米配小米或燕麦，B 族维生素和膳食纤维更丰富，肠道更通畅。", "早餐或晚餐的主食时段", listOf(
                    "小米和大米按 1:1 淘洗干净",
                    "加 6-8 倍水，大火煮开转小火熬 30 分钟成稠粥",
                    "配肉末和碎菜一起吃，营养更均衡",
                    "也可用电饭煲杂粮饭模式做软饭",
                )),
                BabyFood("清蒸鱼块", "steamed_fish", "DHA 和优质蛋白持续供应大脑发育，每周吃鱼 2-3 次为宜。", "午餐时段，每周 2-3 次", listOf(
                    "鳕鱼 / 鲈鱼段冲洗，摆盘铺两片姜去腥",
                    "水开上锅蒸 8-10 分钟",
                    "出锅后仔细挑净鱼刺、去掉鱼皮",
                    "压成小块直接吃，1 岁后也可不调味",
                ), "吃鱼时务必再检查一遍小刺。"),
                BabyFood("番茄炖牛腩", "tomato_beef", "番茄的维生素 C 促进牛肉里铁的吸收，酸甜开胃；炖到软烂好嚼不塞牙。", "午餐时段（炖煮时间长，适合周末多做）", listOf(
                    "牛腩切小块冷水下锅焯水，撇净浮沫",
                    "番茄去皮切块，小火炒出汁",
                    "加牛腩和热水，小火炖 60-90 分钟至软烂",
                    "剪成小丁连汤拌饭，不加盐或少盐",
                )),
                BabyFood("时蔬鸡蛋小饼", "veggie_bites", "蛋白质、碳水、蔬菜一饼俱全，切条后自己抓着吃，锻炼咀嚼和手眼协调。", "早餐，或下午加餐", listOf(
                    "鸡蛋 + 面粉 + 西葫芦 / 胡萝卜碎，调成稠酸奶状糊",
                    "平底锅刷薄油，小火摊成小圆饼",
                    "每面煎 2-3 分钟，至熟透微黄",
                    "切成小条放温再给",
                )),
                BabyFood("奶酪 / 奶制品加餐", "cheese", "浓缩的钙和蛋白质，是长骨骼和牙齿的主力加餐。", "上午或下午加餐，每天 1-2 小块", listOf(
                    "选婴儿奶酪或低钠原味奶酪（钠越低越好）",
                    "切成 1cm 小块，放至室温再给",
                    "也可用无糖酸奶拌水果块替换",
                    "吃完喝几口水，防奶酪渣粘牙",
                ), "选钠含量低的品种，每天 1-2 小块即可。"),
                BabyFood("水果块", "fruit_cubes", "直接啃水果块锻炼咀嚼，补充维生素 C 和膳食纤维；整果永远比果汁好。", "上午或下午加餐、正餐后的水果时段", listOf(
                    "香蕉、草莓、火龙果等软果去皮，切 1cm 小块",
                    "苹果等硬果先蒸 5 分钟蒸软再切",
                    "整颗葡萄、圣女果必须切四瓣",
                    "大人在旁看着吃，坐好吃、不跑跳",
                ), "圆滑硬质水果（整颗葡萄、圣女果）要切四瓣防呛噎。"),
                BabyFood("豆腐蔬菜丸子", "tofu_balls", "植物蛋白+蔬菜混搭，营养密度高，丸子形状让宝宝更愿意吃蔬菜。", "午餐或晚餐，配主食一起", listOf(
                    "老豆腐压碎，挤干水分",
                    "加胡萝卜碎、少许淀粉和蛋清，顺一个方向拌匀",
                    "搓成鹌鹑蛋大小的丸子",
                    "水开上锅蒸 12 分钟，或小火煮熟即可",
                )),
            ),
        ),
        FoodStage(
            "2-3 岁", "幼儿期 · 三餐两点",
            "和全家吃一样的三餐 + 两点，只是少盐少糖、食材切小块；每天奶量 350-500ml。固定餐位、不追喂不哄喂，鼓励自己吃完一整餐。",
            listOf(
                BabyFood("全麦小馒头 / 发糕", "steamed_bun", "全谷的膳食纤维预防便秘，B 族维生素丰富；发糕松软好嚼，接受度高。", "早餐主食，或下午加餐", listOf(
                    "面粉 + 奶粉 + 酵母 + 温水，揉成光滑面团",
                    "盖保鲜膜发酵至 1.5 倍大（约 40 分钟）",
                    "揉面排气后做形，可掺南瓜泥、红枣碎",
                    "冷水上锅，水开后蒸 15 分钟，关火焖 3 分钟再开盖",
                )),
                BabyFood("时蔬蛋炒饭", "fried_rice", "一碗里同时有主食、蛋和多种蔬菜，色彩丰富，是对付挑食的好办法。", "午餐或晚餐的主食时段", listOf(
                    "胡萝卜、玉米、豌豆提前煮软",
                    "鸡蛋炒散，盛出备用",
                    "少油下软米饭炒散，加入蔬菜丁和鸡蛋",
                    "小火炒软炒透，盐控制在 1g 以内或用香菇提鲜",
                )),
                BabyFood("清蒸鱼 / 白灼虾", "fish_shrimp", "DHA、碘、锌持续供应大脑与体格发育，每周水产 2-3 次。", "午餐或晚餐，每周水产 2-3 次", listOf(
                    "龙利鱼 / 鲈鱼段铺姜片，水开蒸 8 分钟",
                    "鲜虾水开下锅白灼 3-4 分钟，至变红卷曲",
                    "虾去壳切段，鱼挑净刺",
                    "都不需要重调味，可挤两滴柠檬汁去腥",
                )),
                BabyFood("小米南瓜粥", "millet_pumpkin", "养胃好消化，β-胡萝卜素+膳食纤维双补，肠胃不舒服或腹泻恢复期也很友好。", "早餐或晚餐主食，肠胃不适时也适合", listOf(
                    "小米淘洗，南瓜去皮切小块",
                    "一起下锅加 8 倍水，大火煮开",
                    "转小火煮 30 分钟至软糯，中途搅两次防粘底",
                    "熬到南瓜化在粥里，最香甜",
                )),
                BabyFood("水果酸奶杯", "yogurt_cup", "加餐界的营养优等生：蛋白质、钙、益生菌、维生素 C 一次到位。", "下午加餐时段（约 15:00）", listOf(
                    "无糖酸奶倒入小杯，铺一层",
                    "加一层切碎的时令水果",
                    "再撒一小勺即食燕麦片，层层叠加",
                    "做好马上吃，放久了燕麦会泡软",
                )),
                BabyFood("迷你鸡肉蔬菜丸", "chicken_balls", "肉菜混搭营养密度高，自己捏着吃还能练精细动作。", "午餐或晚餐配菜，也方便当加餐带出门", listOf(
                    "鸡肉末 + 胡萝卜碎 + 少许淀粉，顺一个方向搅打上劲",
                    "搓成直径约 2cm 的迷你丸子",
                    "水微开下锅煮 6-8 分钟，全部浮起即熟",
                    "也可上锅蒸 12 分钟，一次多做些冷冻保存",
                )),
                BabyFood("无糖豆浆 / 豆腐脑", "soy_milk", "植物蛋白和钙的好来源，乳糖不耐受宝宝的替代选择。", "早餐时段，配主食一起", listOf(
                    "干黄豆泡发 8 小时以上，加水打成豆浆",
                    "必须彻底煮沸后再继续煮 5 分钟以上（防皂苷引起恶心呕吐）",
                    "放温至不烫口再给",
                    "也可买现成无糖豆腐脑，直接当早餐",
                )),
            ),
        ),
    )
}

// MARK: 辅食推荐页

@Composable
fun FoodScreen(onBack: () -> Unit) {
    val child = Store.current
    var stageIdx by remember { mutableIntStateOf(BabyFoodLibrary.stageIndex(monthsOf(child))) }
    var expanded by remember { mutableStateOf<String?>(null) }
    val stage = BabyFoodLibrary.stages[stageIdx]

    Column(Modifier.fillMaxSize().background(Palette.background)) {
        TopBar(title = "辅食推荐", onBack = onBack)
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(top = 10.dp, bottom = 20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // 月龄段选择
            item {
                Row(
                    Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    BabyFoodLibrary.stages.forEachIndexed { i, s ->
                        val active = i == stageIdx
                        Text(
                            s.label,
                            fontSize = 13.sp,
                            fontWeight = if (active) FontWeight.SemiBold else FontWeight.Normal,
                            color = if (active) Color.White else Palette.ink,
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(if (active) Palette.purple else Palette.card)
                                .clickable {
                                    stageIdx = i
                                    expanded = null
                                }
                                .padding(horizontal = 14.dp, vertical = 8.dp),
                        )
                    }
                }
            }
            // 阶段说明卡
            item {
                Column(
                    Modifier.padding(horizontal = 16.dp).fillMaxWidth().cardStyle(padding = 14.dp),
                ) {
                    Text(stage.subtitle, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
                    Text(
                        stage.feeding, fontSize = 12.5.sp, color = Palette.ink2,
                        lineHeight = 18.sp, modifier = Modifier.padding(top = 5.dp),
                    )
                }
            }
            // 辅食列表
            items(stage.foods, key = { it.name }) { food ->
                Column(Modifier.padding(horizontal = 16.dp)) {
                    Column(Modifier.fillMaxWidth().cardStyle(padding = 0.dp)) {
                        Row(
                            Modifier.fillMaxWidth().clickable { expanded = if (expanded == food.name) null else food.name }
                                .padding(horizontal = 14.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            // 食材图片
                            Image(
                                painter = painterResource(id = drawableId(food.img)),
                                contentDescription = food.name,
                                contentScale = ContentScale.Crop,
                                modifier = Modifier.size(46.dp).clip(RoundedCornerShape(11.dp)),
                            )
                            Spacer(Modifier.width(11.dp))
                            Column(Modifier.weight(1f)) {
                                Text(food.name, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.ink)
                                Text(
                                    if (expanded == food.name) food.benefit else food.benefit.take(24) + if (food.benefit.length > 24) "…" else "",
                                    fontSize = 11.5.sp, color = Palette.subtle,
                                    maxLines = if (expanded == food.name) 10 else 1,
                                    lineHeight = 16.sp,
                                )
                            }
                            Text(if (expanded == food.name) "▲" else "▼", fontSize = 10.sp, color = Palette.subtle)
                        }
                        if (expanded == food.name) {
                            Column(Modifier.padding(start = 14.dp, end = 14.dp, bottom = 13.dp)) {
                                // 大图
                                Image(
                                    painter = painterResource(id = drawableId(food.img)),
                                    contentDescription = food.name,
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier.fillMaxWidth().height(170.dp).clip(RoundedCornerShape(12.dp)),
                                )
                                Spacer(Modifier.height(8.dp))
                                // 建议时段
                                Text(
                                    "🕐 ${food.bestTime}",
                                    fontSize = 11.5.sp, fontWeight = FontWeight.Medium, color = Palette.purple,
                                    lineHeight = 16.sp,
                                    modifier = Modifier.fillMaxWidth()
                                        .clip(RoundedCornerShape(9.dp))
                                        .background(Palette.purple.copy(alpha = 0.08f))
                                        .padding(10.dp),
                                )
                                Spacer(Modifier.height(8.dp))
                                FoodBlock(title = "对宝宝的好处", body = food.benefit)
                                Spacer(Modifier.height(8.dp))
                                Text("烹饪步骤", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple)
                                Spacer(Modifier.height(4.dp))
                                food.steps.forEachIndexed { i, step ->
                                    Row(Modifier.padding(bottom = 7.dp), verticalAlignment = Alignment.Top) {
                                        Box(
                                            Modifier.size(16.dp).clip(CircleShape).background(Palette.purple.copy(alpha = 0.85f)),
                                            contentAlignment = Alignment.Center,
                                        ) {
                                            Text("${i + 1}", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color.White)
                                        }
                                        Spacer(Modifier.width(8.dp))
                                        Text(step, fontSize = 12.5.sp, color = Palette.ink2, lineHeight = 18.sp)
                                    }
                                }
                                food.note?.let {
                                    Spacer(Modifier.height(2.dp))
                                    Text(
                                        "⚠️ $it",
                                        fontSize = 11.5.sp, color = Palette.warn,
                                        lineHeight = 16.sp,
                                        modifier = Modifier.fillMaxWidth()
                                            .clip(RoundedCornerShape(9.dp))
                                            .background(Palette.warnBg)
                                            .padding(10.dp),
                                    )
                                }
                            }
                        }
                    }
                }
            }
            item {
                Text(
                    "内容根据国家卫健委婴幼儿喂养科普与儿保常识整理，仅供参考；宝宝生病、过敏或生长发育异常时，请遵医嘱调整。",
                    fontSize = 11.sp, color = Palette.subtle, lineHeight = 15.sp,
                    modifier = Modifier.padding(horizontal = 20.dp),
                )
            }
        }
    }
}

@Composable
private fun FoodBlock(title: String, body: String) {
    Text(title, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.purple)
    Text(body, fontSize = 12.5.sp, color = Palette.ink2, lineHeight = 18.sp, modifier = Modifier.padding(top = 2.dp))
}

/** 把图片 key 转成 drawable 资源 id（资源已放入 res/drawable-nodpi） */
private val drawableIds = mutableMapOf<String, Int>()

private fun drawableId(key: String): Int = drawableIds.getOrPut(key) {
    try {
        R.drawable::class.java.getField(key).getInt(null)
    } catch (_: Exception) {
        0
    }
}

private fun monthsOf(child: Child?): Int = child?.let {
    GrowthMath.ageMonths(it.birthDate, java.time.LocalDate.now())
} ?: 6
