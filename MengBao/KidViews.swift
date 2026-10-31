import SwiftUI

// MARK: - 宝宝档案编辑

struct KidEditorView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let child: Child?

    @State private var name: String
    @State private var sex: Sex
    @State private var birthDate: Date
    @State private var avatar: String
    @State private var showDeleteAlert = false
    @State private var errorMessage: String?

    private let avatars = ["👶", "👧", "👦", "🧒", "🐣", "🐰", "🐻", "🦊"]

    init(child: Child?) {
        self.child = child
        _name = State(initialValue: child?.name ?? "")
        _sex = State(initialValue: child?.sex ?? .boy)
        _birthDate = State(initialValue: child?.birthDate ?? Date())
        _avatar = State(initialValue: child?.displayAvatar ?? "👦")
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
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("头像").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                                ForEach(avatars, id: \.self) { a in
                                    Button { avatar = a } label: {
                                        Text(a).font(.system(size: 21))
                                            .frame(width: 40, height: 40)
                                            .background(avatar == a ? Palette.purpleSoft : Palette.purpleTint)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(avatar == a ? Palette.purple : Palette.hairline, lineWidth: 2))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
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

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "给宝宝起个名字吧"
            return
        }
        if let child = child {
            var updated = child
            updated.name = trimmed
            updated.sex = sex
            updated.birthDate = birthDate
            updated.avatar = avatar
            store.updateChild(updated)
        } else {
            store.addChild(name: trimmed, sex: sex, birthDate: birthDate, avatar: avatar)
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
                            Text(kid.displayAvatar).font(.system(size: 24))
                                .frame(width: 44, height: 44)
                                .background(Palette.purpleSoft)
                                .clipShape(Circle())
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
