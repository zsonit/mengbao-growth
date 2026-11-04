import SwiftUI

// MARK: - 饮食指南（3-18 岁）

struct DietTopic: Identifiable {
    var id: String { title }
    let title: String      // "📏 长高助长"
    let summary: String    // 一句话概括
    let eat: [String]      // 建议多吃
    let avoid: [String]    // 要少吃 / 避免
    let tips: [String]     // 生活提醒
}

struct DietStage: Identifiable {
    let id: Int
    let label: String      // "3-6 岁"
    let subtitle: String
    let daily: String      // 每日饮食要点
}

enum DietGuideLibrary {

    /// 根据年龄返回默认选中的阶段下标
    static func stageIndex(forYears years: Int) -> Int {
        if years <= 6 { return 0 }
        if years <= 12 { return 1 }
        return 2
    }

    static let stages: [DietStage] = [
        DietStage(id: 0, label: "3-6 岁", subtitle: "学龄前 · 习惯养成期", daily: "每天奶 400-500ml、鸡蛋 1 个、肉禽鱼 50-70g、蔬菜水果各 150-200g、谷类 100-150g。三餐 + 两次加餐（上午 10 点、下午 3 点，选水果、酸奶、小量坚果）；口味清淡，每天盐少于 3g、糖少于 25g；固定进餐时间，不追喂、不边看电视边吃。"),
        DietStage(id: 1, label: "7-12 岁", subtitle: "小学期 · 早餐与控糖关键期", daily: "奶 300ml 以上、肉禽鱼蛋合计 120-200g、蔬菜 300g 左右、水果 150-200g。早餐必须吃且要有蛋白质（蛋/奶/豆浆）；每天饮水 1000-1400ml，不喝或少喝含糖饮料；零食首选水果、原味坚果、无糖酸奶；晚饭吃到八分饱，睡前 1 小时不进食。"),
        DietStage(id: 2, label: "13-18 岁", subtitle: "青春期 · 生长第二高峰", daily: "能量需求大：主食足量、蛋白质每天 60-90g（肉蛋奶豆搭配）、奶 500ml。女生注意补铁（瘦红肉、动物血，预防缺铁性贫血）；男生注意锌（海产品、瘦肉）。每天饮水 1400-1600ml；控制奶茶、油炸食品；考试期别靠咖啡和功能饮料硬撑，规律三餐更抗疲劳。"),
    ]

    static let topics: [DietTopic] = [
        DietTopic(
            title: "📏 长高助长",
            summary: "钙 + 蛋白质 + 维生素 D 打底，控糖护睡眠，长高七分靠遗传三分靠喂养",
            eat: [
                "奶制品每天 300-500ml（纯奶 / 无糖酸奶 / 奶酪），是钙的最佳来源",
                "鸡蛋每天 1 个，蛋黄含维生素 D，帮助钙吸收",
                "瘦肉、鱼虾、豆腐每餐掌心大小，蛋白质是骨骼生长的原料",
                "深绿色蔬菜（油菜、芥蓝、西兰花）含钙且维生素 K 帮助钙沉积",
                "深海鱼（三文鱼、沙丁鱼）每周 2 次，补维生素 D；每天户外晒太阳 20-30 分钟",
            ],
            avoid: [
                "碳酸饮料：磷酸影响钙吸收，是长高的大敌",
                "高糖零食、甜点：血糖波动抑制生长激素分泌",
                "补品（蜂王浆、牛初乳、成人蛋白粉）：可能催发性早熟、骨骺提前闭合",
                "睡前加餐过饱：影响深睡眠，错过生长激素分泌高峰",
            ],
            tips: [
                "生长激素在深睡眠分泌最多，尽量晚上 9:30 前入睡",
                "每天户外跳跃类运动 1 小时（跳绳、篮球、摸高）刺激骨骼",
                "身高长期低于同龄第 3 百分位或一年长不到 5cm，查骨龄和生长激素",
            ]
        ),
        DietTopic(
            title: "☀️ 皮肤白净透亮",
            summary: "抗氧化食物 + 严格防晒是核心，控糖控油炸减少长痘和暗沉",
            eat: [
                "富含维生素 C 的果蔬：猕猴桃、橙子、圣女果、彩椒，抑制黑色素生成",
                "熟番茄：番茄红素是天然抗氧化剂，熟吃吸收更好",
                "原味坚果（每天一小把）、深海鱼：维生素 E 和不饱和脂肪酸让皮肤有光泽",
                "足量饮水：3-6 岁 600-800ml，7 岁以上 1000-1500ml",
            ],
            avoid: [
                "高糖食物和奶茶：糖化反应让皮肤暗黄、易长痘（青春期尤其明显）",
                "油炸食品、过量辛辣：刺激皮脂分泌，加重痘痘和毛孔问题",
                "过量柑橘类果汁：高糖且不防晒时可能加重色沉，直接吃果肉更好",
            ],
            tips: [
                "变白的核心是防晒：帽子、遮阳伞等硬防晒最安全，儿童尽量用物理防晒霜",
                "睡眠不足会让皮肤暗沉、修复变慢，保证年龄对应睡眠时长",
                "青春期痘痘严重、持续不消要看皮肤科，别乱用成人美白、祛痘产品",
            ]
        ),
        DietTopic(
            title: "🦷 预防龅牙",
            summary: "足够的咀嚼刺激颌骨发育 + 控糖防蛀，牙不齐很多是「颌骨养小了」",
            eat: [
                "适量耐嚼食物：整块苹果、玉米段、牛肉干（适度），咀嚼促进颌骨发育、给恒牙排齐留空间",
                "粗粮（燕麦、全麦、糙米）：比精软食物更费咀嚼，锻炼咬肌与颌骨",
                "钙 + 维生素 D：巩固牙槽骨和牙釉质",
                "清脆生蔬果当零食（黄瓜条、胡萝卜条）：解馋又练咀嚼",
            ],
            avoid: [
                "长期只吃软烂糊状食物：颌骨缺少咀嚼刺激，牙床太窄导致牙列拥挤、前突",
                "频繁吃糖、含糖酸奶饮料：蛀牙 → 乳牙早失 → 恒牙萌出错位",
                "含着奶瓶入睡、喝完奶不刷牙：奶渍滞留是幼儿蛀牙主因",
                "用口呼吸时的口干环境：唾液少、牙菌斑加速堆积",
            ],
            tips: [
                "戒掉吐舌、咬唇、咬笔、单侧咀嚼等习惯，都会把牙齿顶变形",
                "3-4 岁起每半年口腔检查；乳牙滞留（双排牙）及时拔除",
                "发现「地包天」4 岁左右就能干预；龅牙、牙列拥挤 7-9 岁做早期矫治评估效果最好",
            ]
        ),
        DietTopic(
            title: "👃 预防腺样体肥大",
            summary: "核心是控制过敏和鼻炎，饮食辅助抗炎；打鼾憋气务必看耳鼻喉科",
            eat: [
                "富含维生素 C 和花青素的抗炎食物：蓝莓、西兰花、菠菜、橙子",
                "Omega-3 抗炎：深海鱼每周 2 次，凉拌菜用亚麻籽油",
                "温热饮食，喝温水：减少对鼻咽部黏膜的刺激",
                "过敏体质的孩子先查过敏原，明确并严格避开致敏食物（常见：牛奶蛋白、鸡蛋、坚果）",
            ],
            avoid: [
                "冰饮、大量生冷食物：刺激鼻咽黏膜，加重鼻塞和分泌物",
                "已知过敏原食物：过敏反应会让腺样体和扁桃体反复增生",
                "高糖零食和油炸食品：促进慢性炎症，加重鼻部症状",
                "睡前甜食、牛奶不漱口就睡：夜间咽喉分泌物增多，加重打鼾",
            ],
            tips: [
                "腺样体肥大的关键在控制鼻炎和过敏（尘螨是头号元凶），饮食只是辅助",
                "长期打鼾、张口呼吸、睡眠憋气要尽快看耳鼻喉科，别拖",
                "长期口呼吸会形成「腺样体面容」（上牙前突、下巴后缩）——和龅牙问题直接相关，早干预",
            ]
        ),
        DietTopic(
            title: "👀 护眼明目",
            summary: "叶黄素 + 维生素 A 供营养，但防近视最有效的其实是每天户外 2 小时",
            eat: [
                "深色蔬菜：菠菜、羽衣甘蓝，叶黄素过滤蓝光、保护视网膜",
                "玉米、蛋黄：叶黄素和玉米黄素的好来源",
                "胡萝卜、南瓜、动物肝（每周 1 次少量）：维生素 A 维护夜间视力",
                "蓝莓、桑葚：花青素帮助缓解视疲劳",
            ],
            avoid: [
                "含糖饮料和过多甜食：糖代谢消耗维生素 B1 和钙，与近视进展相关",
                "过多精制主食和零食：血糖波动大，对视力管理不利",
            ],
            tips: [
                "每天 2 小时户外自然光是防近视最有效的手段，比任何食物都管用",
                "用眼遵循 20-20-20：看屏幕或书写 20 分钟，远眺 20 英尺外 20 秒",
                "3 岁起建立视力档案，每半年查一次",
            ]
        ),
        DietTopic(
            title: "💪 改善贫血 · 提高免疫",
            summary: "孩子脸色苍白、容易累，多半先想到缺铁；铁要配着维生素 C 吃",
            eat: [
                "瘦红肉每周 3-4 次、动物肝每周 1 次（每次 10-20g）、动物血：血红素铁吸收率高",
                "搭配维生素 C（橙子、猕猴桃、青椒）促进铁吸收——餐后一个水果就够",
                "菌菇、大蒜：多糖成分帮助调节免疫",
                "酸奶等发酵乳制品：维护肠道菌群，肠道好免疫才好",
            ],
            avoid: [
                "餐前大量喝汤、饮料：占据胃容量影响正餐进食",
                "浓茶（青春期少喝）：茶多酚明显抑制铁吸收",
                "长期以奶代饭（3 岁后）：奶喝太多反而挤掉富铁食物，是幼儿贫血常见原因",
            ],
            tips: [
                "孩子面色苍白、乏力、注意力差，先查血常规看血红蛋白",
                "补铁剂和牛奶间隔 2 小时，钙和铁互相抢吸收",
                "反复感冒先看睡眠和运动够不够，饮食均衡比任何「提高免疫」的补品都靠谱",
            ]
        ),
    ]
}

// MARK: - 页面

struct DietGuideView: View {
    let child: Child?
    @State private var stageId: Int = 0
    @State private var expanded: String? = nil

    private var stage: DietStage { DietGuideLibrary.stages[stageId] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 年龄段选择
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DietGuideLibrary.stages) { s in
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
                    Text(stage.daily)
                        .font(.system(size: 12.5))
                        .foregroundColor(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 14)
                .padding(.horizontal, 16)

                // 专题列表
                VStack(spacing: 0) {
                    ForEach(DietGuideLibrary.topics) { topic in
                        DietTopicRow(
                            topic: topic,
                            expanded: expanded == topic.id,
                            onTap: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    expanded = expanded == topic.id ? nil : topic.id
                                }
                            }
                        )
                        if topic.id != DietGuideLibrary.topics.last?.id {
                            Divider().background(Palette.hairlineSoft)
                        }
                    }
                }
                .cardStyle(padding: 0)
                .padding(.horizontal, 16)

                Text("内容根据国家卫健委学生膳食指南与儿科 / 口腔 / 耳鼻喉科科普常识整理，仅供参考；孩子有明确疾病或生长异常时，请遵医嘱调整。")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
            .padding(.top, 12)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("饮食指南 3-18 岁")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let child = child {
                let y = Calendar.current.dateComponents([.year], from: child.birthDate, to: Date()).year ?? 0
                stageId = DietGuideLibrary.stageIndex(forYears: y)
            }
        }
    }
}

private struct DietTopicRow: View {
    let topic: DietTopic
    let expanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(alignment: .center, spacing: 10) {
                    Text(String(topic.title.prefix(2)))
                        .font(.system(size: 17))
                    Text(topic.summary)
                        .font(.system(size: 14, weight: expanded ? .semibold : .regular))
                        .foregroundColor(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Palette.subtle)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(14)
            }
            .buttonStyle(SoftPressStyle())

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    dietSection("✅ 建议多吃", items: topic.eat, color: Palette.ok)
                    dietSection("🚫 要少吃 / 避免", items: topic.avoid, color: Palette.bad)
                    dietSection("💡 生活提醒", items: topic.tips, color: Palette.purple)
                }
                .padding(14)
                .background(Palette.background)
            }
        }
    }

    @ViewBuilder
    private func dietSection(_ title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(color)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("·").font(.system(size: 13, weight: .bold)).foregroundColor(color)
                    Text(item)
                        .font(.system(size: 12.5))
                        .foregroundColor(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
            }
        }
    }
}
