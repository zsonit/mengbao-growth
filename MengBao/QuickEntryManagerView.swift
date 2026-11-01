import SwiftUI

// MARK: - 快捷入口管理

/// 从首页「⚙️ 配置」push 进来。列表常开编辑态，右侧拖动条可以直接拖着排序。
struct QuickEntryManagerView: View {
    @EnvironmentObject private var store: Store

    @State private var editMode: EditMode = .active
    @State private var showAdd = false
    @State private var showReset = false

    private var allEntries: [QuickEntry] { store.quickEntries }
    private var showingEntries: [QuickEntry] { allEntries.filter { $0.visible } }
    private var hiddenEntries: [QuickEntry] { allEntries.filter { !$0.visible } }

    private let pastel: [Color] = [Palette.purpleTint, Palette.pinkBg, Palette.blueBg, Palette.okBg,
                                   Palette.warnBg, Palette.purpleSoft]

    var body: some View {
        List {
            Section {
                if showingEntries.isEmpty {
                    Text("没有显示中的入口，去下面打开一个")
                        .font(.system(size: 13))
                        .foregroundColor(Palette.subtle)
                }
                ForEach(showingEntries) { entry in
                    row(entry)
                }
                .onMove { source, destination in
                    moveShowing(from: source, to: destination)
                }
            } header: {
                Text("显示中（\(showingEntries.count)）").font(.system(size: 12, weight: .semibold))
            } footer: {
                Text("长按右侧拖动条可以调整首页顺序。")
                    .font(.system(size: 11.5))
            }

            if !hiddenEntries.isEmpty {
                Section {
                    ForEach(hiddenEntries) { entry in
                        row(entry)
                    }
                } header: {
                    Text("已隐藏（\(hiddenEntries.count)）").font(.system(size: 12, weight: .semibold))
                } footer: {
                    Text("隐藏的入口不会出现在首页横滑里，但记录都还在。")
                        .font(.system(size: 11.5))
                }
            }

        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("快捷入口管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("快捷入口管理")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Palette.ink)
                    Text("自定义首页记录入口")
                        .font(.system(size: 10))
                        .foregroundColor(Palette.subtle)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showReset = true
                } label: {
                    Text("恢复默认")
                        .font(.system(size: 13))
                        .foregroundColor(Palette.purple)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showAdd = true
            } label: {
                Text("＋ 自定义入口")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Palette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Palette.purple.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(SoftPressStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .background(Palette.background.opacity(0.96))
        }
        .sheet(isPresented: $showAdd) {
            AddQuickEntrySheet()
        }
        .confirmationDialog("恢复默认快捷入口？", isPresented: $showReset, titleVisibility: .visible) {
            Button("恢复默认", role: .destructive) { store.resetQuickEntries() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("会清空自定义入口，并把内置入口恢复成默认顺序与显示状态。")
        }
    }

    // MARK: 行

    private func row(_ entry: QuickEntry) -> some View {
        HStack(spacing: 11) {
            Text(entry.icon)
                .font(.system(size: 17))
                .frame(width: 34, height: 34)
                .background(pastel[colorIndex(entry)])
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundColor(entry.visible ? Palette.ink : Palette.subtle)
                Text(entry.visible ? "显示中" : "已隐藏")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.subtle)
            }

            Spacer(minLength: 6)

            Button {
                store.toggleQuickEntry(entry.id)
            } label: {
                Image(systemName: entry.visible ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(entry.visible ? Palette.ok : Palette.subtle.opacity(0.4))
            }
            .buttonStyle(.borderless)

            if !entry.isBuiltin {
                Button {
                    store.deleteQuickEntry(entry.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(Palette.bad.opacity(0.8))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 3)
        .opacity(entry.visible ? 1 : 0.6)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                store.toggleQuickEntry(entry.id)
            } label: {
                Label(entry.visible ? "隐藏" : "显示", systemImage: entry.visible ? "eye.slash" : "eye")
            }
            if !entry.isBuiltin {
                Button(role: .destructive) {
                    store.deleteQuickEntry(entry.id)
                } label: {
                    Label("删除入口", systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !entry.isBuiltin {
                Button(role: .destructive) {
                    store.deleteQuickEntry(entry.id)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }

    private func colorIndex(_ entry: QuickEntry) -> Int {
        let index = allEntries.firstIndex(where: { $0.id == entry.id }) ?? 0
        return index % pastel.count
    }

    // MARK: 排序

    /// 只重排「显示中」那一段，隐藏项保持原来的相对位置
    private func moveShowing(from source: IndexSet, to destination: Int) {
        var showing = showingEntries
        showing.move(fromOffsets: source, toOffset: destination)
        var queue = showing
        let merged = allEntries.map { entry -> QuickEntry in
            guard entry.visible, !queue.isEmpty else { return entry }
            return queue.removeFirst()
        }
        store.setQuickEntries(merged)
    }
}

// MARK: - 新增自定义入口

private struct AddQuickEntrySheet: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var icon = "🍬"

    private let icons = ["🍬", "🍎", "🚼", "🧸", "💧", "🛁", "🦷", "🎵", "☀️", "🌙", "🧴", "💩"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("名称").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                        TextField("例如：洗澡、量体温、喂药", text: $title)
                            .font(.system(size: 15))
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.purpleTint)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("图标").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(icons, id: \.self) { item in
                                Button {
                                    icon = item
                                } label: {
                                    Text(item)
                                        .font(.system(size: 20))
                                        .frame(width: 44, height: 44)
                                        .background(icon == item ? Palette.purpleSoft : Palette.purpleTint)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(icon == item ? Palette.purple : Color.clear, lineWidth: 1.5)
                                        )
                                }
                                .buttonStyle(SoftPressStyle())
                            }
                        }
                    }

                    Button("添加") {
                        store.addCustomQuickEntry(title: title.trimmed(), icon: icon)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(title.trimmed().isEmpty)
                    .opacity(title.trimmed().isEmpty ? 0.5 : 1)
                    .padding(.top, 4)

                    Text("添加后会出现在首页横滑的最后，可以在列表里拖动调整位置。")
                        .font(.system(size: 11.5))
                        .foregroundColor(Palette.subtle)
                }
                .padding(16)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("自定义入口")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
