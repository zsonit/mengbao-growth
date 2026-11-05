import SwiftUI
import PhotosUI

// MARK: - 宝宝档案编辑

struct KidEditorView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let child: Child?

    @State private var name: String
    @State private var sex: Sex
    @State private var birthDate: Date
    @State private var avatar: String
    @State private var avatarPath: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var cropItem: CropImage?      // 选完照片先进入裁剪
    @State private var showDeleteAlert = false
    @State private var errorMessage: String?
    @State private var bdaySameDayOn: Bool
    @State private var bdaySameDayTime: Date
    @State private var bdayAdvanceOn: Bool
    @State private var bdayAdvanceDays: Int
    @State private var bdayAdvanceTime: Date

    private let avatars = ["👶", "👧", "👦", "🧒", "🐣", "🐰", "🐻", "🦊"]

    private static func timeDate(minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    init(child: Child?) {
        self.child = child
        _name = State(initialValue: child?.name ?? "")
        _sex = State(initialValue: child?.sex ?? .boy)
        _birthDate = State(initialValue: child?.birthDate ?? Date())
        _avatar = State(initialValue: child?.displayAvatar ?? "👦")
        _avatarPath = State(initialValue: child?.avatarPath)
        _bdaySameDayOn = State(initialValue: child?.bdaySameDayEnabled ?? true)
        _bdaySameDayTime = State(initialValue: Self.timeDate(minutes: child?.bdaySameDayMinutes ?? 9 * 60))
        _bdayAdvanceOn = State(initialValue: child?.bdayAdvanceEnabled ?? true)
        _bdayAdvanceDays = State(initialValue: child?.bdayAdvanceDaysEffective ?? 1)
        _bdayAdvanceTime = State(initialValue: Self.timeDate(minutes: child?.bdayAdvanceMinutes ?? 9 * 60))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 12) {
                        field(title: "宝宝昵称") {
                            TextField("如：小满", text: $name).font(.system(size: 16, weight: .semibold))
                        }
                        field(title: "出生日期") {
                            DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("性别（决定使用哪套生长标准）").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                            HStack(spacing: 10) {
                                ForEach(Sex.allCases) { s in
                                    Button {
                                        sex = s
                                        if avatars.contains(avatar) { avatar = s.symbol }
                                    } label: {
                                        ChipLabel(text: s.label, selected: sex == s, icon: s.symbol)
                                    }
                                    .buttonStyle(SoftPressStyle())
                                }
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("头像").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                                ForEach(avatars, id: \.self) { a in
                                    Button {
                                        if avatarPath != nil { child?.removeAvatarPhoto() }
                                        avatar = a
                                        avatarPath = nil
                                        photoItem = nil
                                    } label: {
                                        Text(a).font(.system(size: 21))
                                            .frame(width: 40, height: 40)
                                            .background(avatar == a && avatarPath == nil ? Palette.purpleSoft : Palette.purpleTint)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(avatar == a && avatarPath == nil ? Palette.purple : Palette.hairline, lineWidth: 2))
                                    }
                                    .buttonStyle(SoftPressStyle())
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // 照片头像：新增宝宝和编辑档案都可以设置，选完照片可缩放/拖动裁剪
                        VStack(alignment: .leading, spacing: 8) {
                            Text("照片头像（设置后优先显示）").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                            HStack(spacing: 14) {
                                AvatarView(child: previewChild, size: 56, fontSize: 26)
                                PhotosPicker(selection: $photoItem, matching: .images) {
                                    Text(avatarPath != nil ? "📷 更换照片" : "📷 从相册选一张照片")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Palette.purple)
                                        .padding(.horizontal, 14).padding(.vertical, 9)
                                        .background(Palette.purpleTint)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(SoftPressStyle())
                                if avatarPath != nil {
                                    Button("移除") {
                                        // 直接删除当前 avatarPath 对应的文件（新增/编辑都适用）
                                        if let p = avatarPath {
                                            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                                            try? FileManager.default.removeItem(at: docs.appendingPathComponent(p))
                                        }
                                        avatarPath = nil
                                        photoItem = nil
                                    }
                                    .font(.system(size: 13))
                                    .foregroundColor(Palette.bad)
                                    .padding(.horizontal, 12).padding(.vertical, 9)
                                    .background(Palette.badBg)
                                    .clipShape(Capsule())
                                    .buttonStyle(SoftPressStyle())
                                }
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // 生日提醒：当天 / 提前 两个独立开关，时间各自可调
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(isOn: $bdaySameDayOn) {
                                Text("🎂 当天生日提醒")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Palette.ink)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Palette.purple))
                            if bdaySameDayOn {
                                DatePicker(
                                    "",
                                    selection: $bdaySameDayTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Toggle(isOn: $bdayAdvanceOn) {
                                Text("🎁 生日提前提醒")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Palette.ink)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Palette.purple))
                            if bdayAdvanceOn {
                                HStack(spacing: 6) {
                                    Text("提前")
                                        .font(.system(size: 13))
                                        .foregroundColor(Palette.ink2)
                                    Picker("", selection: $bdayAdvanceDays) {
                                        ForEach([1, 2, 3, 5, 7], id: \.self) { d in
                                            Text("\(d) 天").tag(d)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    Text("· 提醒时间")
                                        .font(.system(size: 13))
                                        .foregroundColor(Palette.ink2)
                                    DatePicker(
                                        "",
                                        selection: $bdayAdvanceTime,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .labelsHidden()
                                }
                            }
                            Text("两个提醒可独立开关，时间都能自由调节，到点会推送生日提醒。")
                                .font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .cardStyle()

                    if let errorMessage = errorMessage {
                        Text(errorMessage).font(.system(size: 13)).foregroundColor(Palette.bad)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12).background(Palette.badBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button(child == nil ? "创建档案" : "保存档案") { save() }
                        .buttonStyle(PrimaryButtonStyle())

                    if child != nil {
                        Button("删除这个宝宝") { showDeleteAlert = true }
                            .buttonStyle(PrimaryButtonStyle(filled: false))
                            .foregroundColor(Palette.bad)
                    }

                    Text("出生日期决定月龄与百分位计算，请填写准确。早产宝宝的矫正月龄可写在备注里，评估时以医生意见为准。")
                        .font(.system(size: 12)).foregroundColor(Palette.subtle).lineSpacing(3)
                }
                .padding(16)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle(child == nil ? "添加宝宝" : "编辑档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .onChange(of: photoItem) { item in
                guard let item else { return }
                item.loadTransferable(type: Data.self) { result in
                    if case .success(let data?) = result, let img = UIImage(data: data) {
                        DispatchQueue.main.async {
                            photoItem = nil
                            // 先进入裁剪：可缩放 / 拖动调整角度
                            cropItem = CropImage(image: img)
                        }
                    }
                }
            }
            .sheet(item: $cropItem) { ci in
                AvatarCropView(source: ci.image) { cropped in
                    if child != nil {
                        var target = child!
                        if target.saveAvatarPhoto(cropped) != nil {
                            avatarPath = target.avatarPath
                        }
                    } else {
                        // 新增宝宝：先写入临时档案的文件（预览立即可见），创建档案时把路径写回
                        var tmp = Child(name: name.isEmpty ? "宝宝" : name, sex: sex, birthDate: birthDate, avatar: avatar)
                        if tmp.saveAvatarPhoto(cropped) != nil {
                            avatarPath = tmp.avatarPath
                        }
                    }
                }
            }
            .alert("删除这个宝宝？", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    if let child = child { store.deleteChild(child.id) }
                    dismiss()
                }
            } message: {
                Text("将同时删除该宝宝的全部生长、喂养与接种记录，且无法撤销。")
            }
        }
    }

    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11.5)).foregroundColor(Palette.subtle)
            content()
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.purpleTint)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var previewChild: Child? {
        if var c = child {
            c.avatarPath = avatarPath
            return c
        }
        // 新增宝宝：用当前填写的信息生成预览
        var c = Child(name: name.isEmpty ? "宝宝" : name, sex: sex, birthDate: birthDate, avatar: avatar)
        c.avatarPath = avatarPath
        return c
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "给宝宝起个名字吧"
            return
        }
        if let child = child {
            var updated = child
            let c = Calendar.current
            updated.name = trimmed
            updated.sex = sex
            updated.birthDate = birthDate
            updated.avatar = avatar
            updated.avatarPath = avatarPath
            updated.bdaySameDayOn = bdaySameDayOn
            updated.bdaySameDayTime = c.component(.hour, from: bdaySameDayTime) * 60 + c.component(.minute, from: bdaySameDayTime)
            updated.bdayAdvanceOn = bdayAdvanceOn
            updated.bdayAdvanceDays = bdayAdvanceDays
            updated.bdayAdvanceTime = c.component(.hour, from: bdayAdvanceTime) * 60 + c.component(.minute, from: bdayAdvanceTime)
            // 兼容旧版本：总开关 = 两者任一开启；旧字段时间沿用当天提醒时间
            updated.birthdayRemind = bdaySameDayOn || bdayAdvanceOn
            updated.birthdayTime = updated.bdaySameDayTime
            store.updateChild(updated)
        } else {
            let newID = store.addChild(name: trimmed, sex: sex, birthDate: birthDate, avatar: avatar)
            // 新增宝宝时选了照片：临时文件已在盘上，写回 avatarPath
            if avatarPath != nil, var c = store.state.children.first(where: { $0.id == newID }) {
                c.avatarPath = avatarPath
                store.updateChild(c)
            }
        }
        dismiss()
    }
}

// MARK: - 宝宝列表

struct KidsListView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(store.state.children) { kid in
                        HStack(spacing: 12) {
                            AvatarView(child: kid, size: 44, fontSize: 24, bg: Palette.purpleSoft)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kid.name).font(.system(size: 15, weight: .semibold)).foregroundColor(Palette.ink)
                                Text("\(kid.sex.label) · \(GrowthMath.ageText(from: kid.birthDate))")
                                    .font(.system(size: 12)).foregroundColor(Palette.subtle)
                            }
                            Spacer()
                            if kid.id == store.state.currentID {
                                TagView(text: "当前", tone: .ok)
                            } else {
                                Button("切换") { store.selectChild(kid.id); dismiss() }
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(Palette.purple)
                            }
                        }
                        .padding(14)
                        .background(Palette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.hairline, lineWidth: 1))
                    }

                    Button("＋ 添加宝宝") { showAdd = true }
                        .buttonStyle(PrimaryButtonStyle(filled: false))
                }
                .padding(16)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("管理宝宝")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
            .sheet(isPresented: $showAdd) { KidEditorView(child: nil) }
        }
    }
}
