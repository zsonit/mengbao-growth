package com.zsonit.mengbao.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zsonit.mengbao.data.GrowthMath
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.ui.*

// MARK: 辅食数据

data class BabyFood(
    val emoji: String,
    val name: String,
    val benefit: String,   // 对宝宝的作用 / 健康好处
    val recipe: String,    // 做法
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
                BabyFood("🥣", "强化铁米粉", "强化了铁，正好补上 6 个月后宝宝体内储备铁的下降，预防缺铁性贫血；质地细腻好消化，是最稳妥的第一口辅食。", "取 1-2 勺米粉，用温奶或温水冲调成酸奶般的稀糊，用软勺喂；适应 3-5 天后逐渐加量、调稠。", "选「婴幼儿强化铁」米粉，自家磨的米糊铁不够，不能替代。"),
                BabyFood("🥩", "猪肉泥 / 牛肉泥", "红肉是血红素铁和锌的最佳来源，吸收率高，是预防贫血的主力；蛋白质支持生长发育。", "里脊去筋膜，冷水下锅煮熟，加少量温水打成细泥；可拌入米粉里一起喂。", "初期要打成无明显颗粒的细泥。"),
                BabyFood("🎃", "南瓜泥", "β-胡萝卜素在体内转化为维生素 A，护眼护皮肤、增强抵抗力；口味清甜宝宝容易接受。", "南瓜去皮切小块蒸 12-15 分钟，压成泥过筛；太稠可加温水或奶调稀。"),
                BabyFood("🥦", "西兰花泥", "维生素 C 促进铁吸收，叶酸和膳食纤维帮助肠道发育。", "小朵盐水浸泡后煮至软烂，取花蕾部分打泥；可与米粉或土豆泥混合。"),
                BabyFood("🍎", "苹果泥", "果胶（膳食纤维）温和调理肠道；生苹果泥偏通便，蒸熟的偏收敛止泻。", "苹果去皮去核切块，蒸 8-10 分钟后压成泥；小月龄建议蒸熟更温和。"),
                BabyFood("🥔", "土豆泥", "碳水化合物提供能量，性质温和、不易胀气不易过敏，适合做蔬菜类打底。", "土豆去皮切块蒸 15 分钟至筷子能扎透，趁热压泥，加温水/奶调成细滑糊。"),
                BabyFood("🥚", "蛋黄（7 月龄起）", "含铁、卵磷脂和胆碱，对大脑和神经系统发育很重要。", "鸡蛋冷水下锅煮 8-10 分钟，取蛋黄压泥，从 1/4 个开始混入米粉或粥里。", "每次加量后观察 3 天，无皮疹呕吐再逐步加到半个、整个。"),
            ),
        ),
        FoodStage(
            "7-9 月龄", "蠕嚼期 · 碎末与手指食物",
            "每天 1-2 次辅食，从细泥过渡到稍粗的碎末状，让宝宝练习蠕嚼；可以给蒸软的手指食物让他自己抓着吃。奶量保持 600ml 左右。",
            listOf(
                BabyFood("🍖", "猪肝泥 / 鸡肝泥", "铁和维生素 A 密度很高，是轻度贫血宝宝的首选食材。", "猪肝清水浸泡 30 分钟去血水，煮熟后打泥，分小份冷冻；拌入粥或面里喂。", "每周 1-2 次即可，维生素 A 过量反而不好。"),
                BabyFood("🐟", "三文鱼泥 / 鳕鱼泥", "DHA 助力大脑和视网膜发育，肉质软嫩、刺少。", "鱼块蒸熟，仔细挑净小刺，压成泥或小碎末拌进粥里。", "第一次吃先给一小勺观察过敏反应。"),
                BabyFood("🍲", "内酯豆腐", "优质植物蛋白和钙，质地嫩滑几乎不用嚼，过敏风险低。", "嫩豆腐沸水焯 1 分钟去豆腥，压碎直接拌入粥、面里。", "选内酯豆腐/嫩豆腐，老豆腐偏硬不适合。"),
                BabyFood("🥚", "全蛋蒸蛋羹", "9 月龄左右可以尝试全蛋；蛋白质和卵磷脂丰富，蒸蛋嫩滑易吞咽。", "1 个全蛋加 1.5 倍温水打匀过筛，盖保鲜膜扎几个孔，中小火蒸 10 分钟。", "确诊鸡蛋过敏的宝宝推迟添加并咨询医生。"),
                BabyFood("🍜", "烂面条", "从糊状过渡到软烂颗粒，锻炼咀嚼和吞咽节奏，碳水供能扎实。", "婴儿面条掰短煮到软烂，加菜末、肝泥、蛋黄碎同煮 2 分钟；可不加或只加一点婴儿酱油。"),
                BabyFood("🍌", "香蕉 / 牛油果压泥", "牛油果富含不饱和脂肪酸（好脂肪）帮助大脑发育，香蕉补钾、润肠通便；两者能量密度高。", "熟透香蕉用勺压成粗泥；牛油果取果肉压泥，可混奶或米粉调节稠度。"),
                BabyFood("🥕", "手指食物（蒸胡萝卜条）", "锻炼捏握能力和自主进食意识，熟悉不同食物质地，为咀嚼打基础。", "胡萝卜切小指粗的条，蒸 10-12 分钟到「软而不断」，放餐盘让宝宝自己抓。", "吃的时候大人必须在旁边看护。"),
            ),
        ),
        FoodStage(
            "10-12 月龄", "咀嚼期 · 软小块",
            "每天 2-3 次辅食，性状从碎末过渡到软小块（约香蕉硬度），鼓励自己抓吃；奶量 500-600ml。整颗坚果、果冻、整粒葡萄等呛噎风险食物一定不要给。",
            listOf(
                BabyFood("🍚", "软米饭 / 稠粥", "主食升级，练习用牙龈咀嚼软块，为接受家庭餐做准备。", "米水比约 1:2.5 煮成软饭，配肉末、碎菜拌匀一起吃。"),
                BabyFood("🦐", "虾仁碎 / 小虾丸", "优质蛋白 + 锌 + 钙，脂肪低；锌帮助味觉发育、改善食欲。", "鲜虾去头壳、挑净虾线，煮熟剁碎；做虾丸则加蛋清顺一个方向搅打上劲，小火煮熟。", "虾是常见过敏原，第一次只给少量。"),
                BabyFood("🥟", "小馄饨 / 小饺子", "一张皮包进肉、菜、蛋多种食材，营养密度高，形状有趣宝宝更爱吃。", "猪肉末+碎菜+少许蛋清拌馅，包成迷你馄饨；煮至浮起后再煮 2 分钟，确保皮软烂。"),
                BabyFood("🍲", "肉末豆腐羹", "动植物蛋白互补、钙丰富，羹状质地好嚼好咽，适合刚长几颗牙的宝宝。", "肉末炒香加水煮开，下嫩豆腐碎煮 3 分钟，水淀粉勾薄芡，最后撒碎青菜。"),
                BabyFood("🥛", "无糖原味酸奶", "牛奶蛋白经发酵更好消化，钙和益生菌有益肠道健康，是很好的加餐。", "选配料表只有「生牛乳+菌种」的无糖酸奶，直接吃或拌水果泥。", "1 岁前牛奶不能当主饮品，但酸奶作辅食是可以的。"),
                BabyFood("🧂", "紫菜虾皮粉", "天然「补钙小帮手」，紫菜还含碘，帮助甲状腺功能和大脑发育。", "无盐虾皮和紫菜干锅小火烘脆，料理机打成粉，每次 1 小勺撒进粥、面里。", "务必选无盐虾皮，成人虾皮钠太高。"),
                BabyFood("🥞", "蔬菜蛋饼", "蛋、菜、主食一张饼全搞定，切成小条还能练自主进食。", "鸡蛋+面粉+碎菜+少量水调成酸奶状糊，小火摊成软饼，切成小条放凉再给。"),
            ),
        ),
        FoodStage(
            "1-2 岁", "学步期 · 家庭餐过渡",
            "一日三餐 + 2 次加餐，和大人同桌吃少盐少糖的家常菜，性状为小块软饭；每天奶量 400-600ml，继续每天补维生素 D。让宝宝自己拿勺，吃得脏一点没关系。",
            listOf(
                BabyFood("🍚", "二米粥 / 杂粮软饭", "大米配小米或燕麦，B 族维生素和膳食纤维更丰富，肠道更通畅。", "小米和大米 1:1 煮成稠粥或软饭，配肉末和碎菜一起吃。"),
                BabyFood("🐟", "清蒸鱼块", "DHA 和优质蛋白持续供应大脑发育，每周吃鱼 2-3 次为宜。", "鳕鱼、鲈鱼段蒸 8-10 分钟，仔细挑净刺后压成小块；1 岁后也可不调味直接吃。", "吃鱼时务必再检查一遍小刺。"),
                BabyFood("🍅", "番茄炖牛腩", "番茄的维生素 C 促进牛肉里铁的吸收，酸甜开胃；炖到软烂好嚼不塞牙。", "牛腩焯水后与番茄块小火炖 60-90 分钟至软烂，剪成小丁连汤拌饭；不加盐或少盐。"),
                BabyFood("🥞", "时蔬鸡蛋小饼", "蛋白质、碳水、蔬菜一饼俱全，切条后自己抓着吃，锻炼咀嚼和手眼协调。", "鸡蛋+面粉+西葫芦/胡萝卜碎调成糊，小火摊成软饼，切小条放温再给。"),
                BabyFood("🧀", "奶酪 / 奶制品加餐", "浓缩的钙和蛋白质，是长骨骼和牙齿的主力加餐。", "选婴儿奶酪或低钠原味奶酪切小块；无糖酸奶拌水果块也很好。", "选钠含量低的品种，每天 1-2 小块即可。"),
                BabyFood("🍓", "水果块", "直接啃水果块锻炼咀嚼，补充维生素 C 和膳食纤维；整果永远比果汁好。", "香蕉、草莓、火龙果等软果切 1cm 小块；苹果等硬果可蒸软再给。", "圆滑硬质水果（整颗葡萄、圣女果）要切四瓣防呛噎。"),
                BabyFood("🍡", "豆腐蔬菜丸子", "植物蛋白+蔬菜混搭，营养密度高，丸子形状让宝宝更愿意吃蔬菜。", "老豆腐压碎挤水，加胡萝卜碎、少许淀粉和蛋清拌勻，搓成小丸蒸熟。"),
            ),
        ),
        FoodStage(
            "2-3 岁", "幼儿期 · 三餐两点",
            "和全家吃一样的三餐 + 两点，只是少盐少糖、食材切小块；每天奶量 350-500ml。固定餐位、不追喂不哄喂，鼓励自己吃完一整餐。",
            listOf(
                BabyFood("🍞", "全麦小馒头 / 发糕", "全谷的膳食纤维预防便秘，B 族维生素丰富；发糕松软好嚼，接受度高。", "面粉+奶粉+酵母发酵后上锅蒸，可掺南瓜泥、红枣碎增加风味。"),
                BabyFood("🍚", "时蔬蛋炒饭", "一碗里同时有主食、蛋和多种蔬菜，色彩丰富，是对付挑食的好办法。", "软米饭+鸡蛋+胡萝卜、玉米、豌豆丁小火炒软，盐控制在 1g 以内或用香菇提鲜。"),
                BabyFood("🦐", "清蒸鱼 / 白灼虾", "DHA、碘、锌持续供应大脑与体格发育，每周水产 2-3 次。", "龙利鱼蒸 8 分钟；鲜虾白灼后去壳切段。都不需要额外重调味。"),
                BabyFood("🎃", "小米南瓜粥", "养胃好消化，β-胡萝卜素+膳食纤维双补，肠胃不舒服或腹泻恢复期也很友好。", "小米与南瓜块同煮 30 分钟至软糯香甜，可做早餐或晚餐主食。"),
                BabyFood("🥣", "水果酸奶杯", "加餐界的营养优等生：蛋白质、钙、益生菌、维生素 C 一次到位。", "无糖酸奶+切碎的时令水果+一小勺燕麦片，层层叠进小杯子里。"),
                BabyFood("🍡", "迷你鸡肉蔬菜丸", "肉菜混搭营养密度高，自己捏着吃还能练精细动作。", "鸡肉末+胡萝卜碎+少许淀粉搅打上劲，搓成迷你丸子，水煮或蒸熟。"),
                BabyFood("🥛", "无糖豆浆 / 豆腐脑", "植物蛋白和钙的好来源，乳糖不耐受宝宝的替代选择。", "自制豆浆必须彻底煮沸再煮 5 分钟以上（防皂苷引起恶心呕吐）；或买现成无糖豆腐脑。"),
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
            contentPadding = PaddingValues(vertical = 10.dp, bottom = 20.dp),
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
                            Text(food.emoji, fontSize = 22.sp)
                            Spacer(Modifier.width(10.dp))
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
                                FoodBlock(title = "对宝宝的好处", body = food.benefit)
                                Spacer(Modifier.height(8.dp))
                                FoodBlock(title = "做法", body = food.recipe)
                                food.note?.let {
                                    Spacer(Modifier.height(8.dp))
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

private fun monthsOf(child: Child?): Int = child?.let {
    GrowthMath.ageMonths(it.birthDate, java.time.LocalDate.now())
} ?: 6
