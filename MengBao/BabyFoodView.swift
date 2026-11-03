import SwiftUI

// MARK: - 辅食推荐（按月龄）

struct BabyFood: Identifiable {
    var id: String { name }  // 同一阶段内名称唯一
    let emoji: String
    let name: String
    let benefit: String     // 对宝宝的作用 / 健康好处
    let recipe: String      // 做法
    let note: String?       // 小提示
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
            BabyFood(emoji: "🥣", name: "强化铁米粉", benefit: "强化了铁，正好补上 6 个月后宝宝体内储备铁的下降，预防缺铁性贫血；质地细腻好消化，是最稳妥的第一口辅食。", recipe: "取 1-2 勺米粉，用温奶或温水冲调成酸奶般的稀糊，用软勺喂；适应 3-5 天后逐渐加量、调稠。", note: "选「婴幼儿强化铁」米粉，自家磨的米糊铁不够，不能替代。"),
            BabyFood(emoji: "🥩", name: "猪肉泥 / 牛肉泥", benefit: "红肉是血红素铁和锌的最佳来源，吸收率高，是预防贫血的主力；蛋白质支持生长发育。", recipe: "里脊去筋膜，冷水下锅煮熟，加少量温水打成细泥；可拌入米粉里一起喂。", note: "初期要打成无明显颗粒的细泥。"),
            BabyFood(emoji: "🎃", name: "南瓜泥", benefit: "β-胡萝卜素在体内转化为维生素 A，护眼护皮肤、增强抵抗力；口味清甜宝宝容易接受。", recipe: "南瓜去皮切小块蒸 12-15 分钟，压成泥过筛；太稠可加温水或奶调稀。", note: nil),
            BabyFood(emoji: "🥦", name: "西兰花泥", benefit: "维生素 C 促进铁吸收，叶酸和膳食纤维帮助肠道发育。", recipe: "小朵盐水浸泡后煮至软烂，取花蕾部分打泥；可与米粉或土豆泥混合。", note: nil),
            BabyFood(emoji: "🍎", name: "苹果泥", benefit: "果胶（膳食纤维）温和调理肠道；生苹果泥偏通便，蒸熟的偏收敛止泻。", recipe: "苹果去皮去核切块，蒸 8-10 分钟后压成泥；小月龄建议蒸熟更温和。", note: nil),
            BabyFood(emoji: "🥔", name: "土豆泥", benefit: "碳水化合物提供能量，性质温和、不易胀气不易过敏，适合做蔬菜类打底。", recipe: "土豆去皮切块蒸 15 分钟至筷子能扎透，趁热压泥，加温水/奶调成细滑糊。", note: nil),
            BabyFood(emoji: "🥚", name: "蛋黄（7 月龄起）", benefit: "含铁、卵磷脂和胆碱，对大脑和神经系统发育很重要。", recipe: "鸡蛋冷水下锅煮 8-10 分钟，取蛋黄压泥，从 1/4 个开始混入米粉或粥里。", note: "每次加量后观察 3 天，无皮疹呕吐再逐步加到半个、整个。"),
        ]),
        FoodStage(id: 1, label: "7-9 月龄", subtitle: "蠕嚼期 · 碎末与手指食物", feeding: "每天 1-2 次辅食，从细泥过渡到稍粗的碎末状，让宝宝练习蠕嚼；可以给蒸软的手指食物让他自己抓着吃。奶量保持 600ml 左右。", foods: [
            BabyFood(emoji: "🍖", name: "猪肝泥 / 鸡肝泥", benefit: "铁和维生素 A 密度很高，是轻度贫血宝宝的首选食材。", recipe: "猪肝清水浸泡 30 分钟去血水，煮熟后打泥，分小份冷冻；拌入粥或面里喂。", note: "每周 1-2 次即可，维生素 A 过量反而不好。"),
            BabyFood(emoji: "🐟", name: "三文鱼泥 / 鳕鱼泥", benefit: "DHA 助力大脑和视网膜发育，肉质软嫩、刺少。", recipe: "鱼块蒸熟，仔细挑净小刺，压成泥或小碎末拌进粥里。", note: "第一次吃先给一小勺观察过敏反应。"),
            BabyFood(emoji: "🍲", name: "内酯豆腐", benefit: "优质植物蛋白和钙，质地嫩滑几乎不用嚼，过敏风险低。", recipe: "嫩豆腐沸水焯 1 分钟去豆腥，压碎直接拌入粥、面里。", note: "选内酯豆腐/嫩豆腐，老豆腐偏硬不适合。"),
            BabyFood(emoji: "🥚", name: "全蛋蒸蛋羹", benefit: "9 月龄左右可以尝试全蛋；蛋白质和卵磷脂丰富，蒸蛋嫩滑易吞咽。", recipe: "1 个全蛋加 1.5 倍温水打匀过筛，盖保鲜膜扎几个孔，中小火蒸 10 分钟。", note: "确诊鸡蛋过敏的宝宝推迟添加并咨询医生。"),
            BabyFood(emoji: "🍜", name: "烂面条", benefit: "从糊状过渡到软烂颗粒，锻炼咀嚼和吞咽节奏，碳水供能扎实。", recipe: "婴儿面条掰短煮到软烂，加菜末、肝泥、蛋黄碎同煮 2 分钟；可不加或只加一点婴儿酱油。", note: nil),
            BabyFood(emoji: "🍌", name: "香蕉 / 牛油果压泥", benefit: "牛油果富含不饱和脂肪酸（好脂肪）帮助大脑发育，香蕉补钾、润肠通便；两者能量密度高。", recipe: "熟透香蕉用勺压成粗泥；牛油果取果肉压泥，可混奶或米粉调节稠度。", note: nil),
            BabyFood(emoji: "🥕", name: "手指食物（蒸胡萝卜条）", benefit: "锻炼捏握能力和自主进食意识，熟悉不同食物质地，为咀嚼打基础。", recipe: "胡萝卜切小指粗的条，蒸 10-12 分钟到「软而不断」，放餐盘让宝宝自己抓。", note: "吃的时候大人必须在旁边看护。"),
        ]),
        FoodStage(id: 2, label: "10-12 月龄", subtitle: "咀嚼期 · 软小块", feeding: "每天 2-3 次辅食，性状从碎末过渡到软小块（约香蕉硬度），鼓励自己抓吃；奶量 500-600ml。整颗坚果、果冻、整粒葡萄等呛噎风险食物一定不要给。", foods: [
            BabyFood(emoji: "🍚", name: "软米饭 / 稠粥", benefit: "主食升级，练习用牙龈咀嚼软块，为接受家庭餐做准备。", recipe: "米水比约 1:2.5 煮成软饭，配肉末、碎菜拌匀一起吃。", note: nil),
            BabyFood(emoji: "🦐", name: "虾仁碎 / 小虾丸", benefit: "优质蛋白 + 锌 + 钙，脂肪低；锌帮助味觉发育、改善食欲。", recipe: "鲜虾去头壳、挑净虾线，煮熟剁碎；做虾丸则加蛋清顺一个方向搅打上劲，小火煮熟。", note: "虾是常见过敏原，第一次只给少量。"),
            BabyFood(emoji: "🥟", name: "小馄饨 / 小饺子", benefit: "一张皮包进肉、菜、蛋多种食材，营养密度高，形状有趣宝宝更爱吃。", recipe: "猪肉末+碎菜+少许蛋清拌馅，包成迷你馄饨；煮至浮起后再煮 2 分钟，确保皮软烂。", note: nil),
            BabyFood(emoji: "🍲", name: "肉末豆腐羹", benefit: "动植物蛋白互补、钙丰富，羹状质地好嚼好咽，适合刚长几颗牙的宝宝。", recipe: "肉末炒香加水煮开，下嫩豆腐碎煮 3 分钟，水淀粉勾薄芡，最后撒碎青菜。", note: nil),
            BabyFood(emoji: "🥛", name: "无糖原味酸奶", benefit: "牛奶蛋白经发酵更好消化，钙和益生菌有益肠道健康，是很好的加餐。", recipe: "选配料表只有「生牛乳+菌种」的无糖酸奶，直接吃或拌水果泥。", note: "1 岁前牛奶不能当主饮品，但酸奶作辅食是可以的。"),
            BabyFood(emoji: "🧂", name: "紫菜虾皮粉", benefit: "天然「补钙小帮手」，紫菜还含碘，帮助甲状腺功能和大脑发育。", recipe: "无盐虾皮和紫菜干锅小火烘脆，料理机打成粉，每次 1 小勺撒进粥、面里。", note: "务必选无盐虾皮，成人虾皮钠太高。"),
            BabyFood(emoji: "🥞", name: "蔬菜蛋饼", benefit: "蛋、菜、主食一张饼全搞定，切成小条还能练自主进食。", recipe: "鸡蛋+面粉+碎菜+少量水调成酸奶状糊，小火摊成软饼，切成小条放凉再给。", note: nil),
        ]),
        FoodStage(id: 3, label: "1-2 岁", subtitle: "学步期 · 家庭餐过渡", feeding: "一日三餐 + 2 次加餐，和大人同桌吃少盐少糖的家常菜，性状为小块软饭；每天奶量 400-600ml，继续每天补维生素 D。让宝宝自己拿勺，吃得脏一点没关系。", foods: [
            BabyFood(emoji: "🍚", name: "二米粥 / 杂粮软饭", benefit: "大米配小米或燕麦，B 族维生素和膳食纤维更丰富，肠道更通畅。", recipe: "小米和大米 1:1 煮成稠粥或软饭，配肉末和碎菜一起吃。", note: nil),
            BabyFood(emoji: "🐟", name: "清蒸鱼块", benefit: "DHA 和优质蛋白持续供应大脑发育，每周吃鱼 2-3 次为宜。", recipe: "鳕鱼、鲈鱼段蒸 8-10 分钟，仔细挑净刺后压成小块；1 岁后也可不调味直接吃。", note: "吃鱼时务必再检查一遍小刺。"),
            BabyFood(emoji: "🍅", name: "番茄炖牛腩", benefit: "番茄的维生素 C 促进牛肉里铁的吸收，酸甜开胃；炖到软烂好嚼不塞牙。", recipe: "牛腩焯水后与番茄块小火炖 60-90 分钟至软烂，剪成小丁连汤拌饭；不加盐或少盐。", note: nil),
            BabyFood(emoji: "🥞", name: "时蔬鸡蛋小饼", benefit: "蛋白质、碳水、蔬菜一饼俱全，切条后自己抓着吃，锻炼咀嚼和手眼协调。", recipe: "鸡蛋+面粉+西葫芦/胡萝卜碎调成糊，小火摊成软饼，切小条放温再给。", note: nil),
            BabyFood(emoji: "🧀", name: "奶酪 / 奶制品加餐", benefit: "浓缩的钙和蛋白质，是长骨骼和牙齿的主力加餐。", recipe: "选婴儿奶酪或低钠原味奶酪切小块；无糖酸奶拌水果块也很好。", note: "选钠含量低的品种，每天 1-2 小块即可。"),
            BabyFood(emoji: "🍓", name: "水果块", benefit: "直接啃水果块锻炼咀嚼，补充维生素 C 和膳食纤维；整果永远比果汁好。", recipe: "香蕉、草莓、火龙果等软果切 1cm 小块；苹果等硬果可蒸软再给。", note: "圆滑硬质水果（整颗葡萄、圣女果）要切四瓣防呛噎。"),
            BabyFood(emoji: "🍡", name: "豆腐蔬菜丸子", benefit: "植物蛋白+蔬菜混搭，营养密度高，丸子形状让宝宝更愿意吃蔬菜。", recipe: "老豆腐压碎挤水，加胡萝卜碎、少许淀粉和蛋清拌勻，搓成小丸蒸熟。", note: nil),
        ]),
        FoodStage(id: 4, label: "2-3 岁", subtitle: "幼儿期 · 三餐两点", feeding: "和全家吃一样的三餐 + 两点，只是少盐少糖、食材切小块；每天奶量 350-500ml。固定餐位、不追喂不哄喂，鼓励自己吃完一整餐。", foods: [
            BabyFood(emoji: "🍞", name: "全麦小馒头 / 发糕", benefit: "全谷的膳食纤维预防便秘，B 族维生素丰富；发糕松软好嚼，接受度高。", recipe: "面粉+奶粉+酵母发酵后上锅蒸，可掺南瓜泥、红枣碎增加风味。", note: nil),
            BabyFood(emoji: "🍚", name: "时蔬蛋炒饭", benefit: "一碗里同时有主食、蛋和多种蔬菜，色彩丰富，是对付挑食的好办法。", recipe: "软米饭+鸡蛋+胡萝卜、玉米、豌豆丁小火炒软，盐控制在 1g 以内或用香菇提鲜。", note: nil),
            BabyFood(emoji: "🦐", name: "清蒸鱼 / 白灼虾", benefit: "DHA、碘、锌持续供应大脑与体格发育，每周水产 2-3 次。", recipe: "龙利鱼蒸 8 分钟；鲜虾白灼后去壳切段。都不需要额外重调味。", note: nil),
            BabyFood(emoji: "🎃", name: "小米南瓜粥", benefit: "养胃好消化，β-胡萝卜素+膳食纤维双补，肠胃不舒服或腹泻恢复期也很友好。", recipe: "小米与南瓜块同煮 30 分钟至软糯香甜，可做早餐或晚餐主食。", note: nil),
            BabyFood(emoji: "🥣", name: "水果酸奶杯", benefit: "加餐界的营养优等生：蛋白质、钙、益生菌、维生素 C 一次到位。", recipe: "无糖酸奶+切碎的时令水果+一小勺燕麦片，层层叠进小杯子里。", note: nil),
            BabyFood(emoji: "🍡", name: "迷你鸡肉蔬菜丸", benefit: "肉菜混搭营养密度高，自己捏着吃还能练精细动作。", recipe: "鸡肉末+胡萝卜碎+少许淀粉搅打上劲，搓成迷你丸子，水煮或蒸熟。", note: nil),
            BabyFood(emoji: "🥛", name: "无糖豆浆 / 豆腐脑", benefit: "植物蛋白和钙的好来源，乳糖不耐受宝宝的替代选择。", recipe: "自制豆浆必须彻底煮沸再煮 5 分钟以上（防皂苷引起恶心呕吐）；或买现成无糖豆腐脑。", note: nil),
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
                HStack(spacing: 10) {
                    Text(food.emoji).font(.system(size: 22))
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
                    Label("对宝宝的好处", systemImage: "heart.fill")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(Palette.purple)
                    Text(food.benefit)
                        .font(.system(size: 12.5)).foregroundColor(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true).lineSpacing(3)

                    Label("做法", systemImage: "fork.knife")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(Palette.purple)
                    Text(food.recipe)
                        .font(.system(size: 12.5)).foregroundColor(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true).lineSpacing(3)

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
