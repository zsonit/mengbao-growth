import SwiftUI
import UniformTypeIdentifiers

// MARK: - 分享面板

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 我的

struct ProfileView: View {
    @EnvironmentObject private var store: Store

    @State private var showKidEditor = false
    @State private var showParents = false
    @State private var showImport = false
    @State private var showReset = false
    @State private var showResetFinal = false
    @State private var showLogSheet = false
    @State private var showSync = false
    @State private var logText = ""
    @State private var shareItem: ShareItem?
    @State private var importMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileCard
                statsGrid
                aiSection
                settingsSection
                childrenSection
                dataSection
                logSection
                aboutSection
                Spacer(minLength: 28)
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showKidEditor) { KidEditorView(child: store.current) }
        .sheet(isPresented: $showParents) { ParentsHeightView() }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(isPresented: $showSync) {
            SyncView()
        }
        .sheet(isPresented: $showLogSheet) {
            NavigationStack {
                ScrollView {
                    Text(logText)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundColor(Palette.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .background(Palette.background.ignoresSafeArea())
                .navigationTitle("运行日志")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("关闭") { showLogSheet = false } }
                }
            }
        }
        .fileImporter(isPresented: $showImport, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        // 清空全部数据：必须连续确认两次才会真正清除（第一次询问、最后一次确认，防误触）
        .alert("清空全部数据？", isPresented: $showReset) {
            Button("取消", role: .cancel) { }
            Button("继续", role: .destructive) { showResetFinal = true }
        } message: {
            Text("第一次确认：所有宝宝与记录都会被删除，建议先导出备份。")
        }
        .alert("最后确认：真的要清空？", isPresented: $showResetFinal) {
            Button("取消", role: .cancel) { }
            Button("确认清空", role: .destructive) { store.reset() }
        } message: {
            Text("第二次确认：此操作不可恢复！所有宝宝、喂养记录、生长记录、待办都会清空（同步的设备也会一起被清空）。确定请点「确认清空」。")
        }
        .alert("导入结果", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
            Button("好") { importMessage = nil }
        } message: {
            Text(importMessage ?? "")
        }
    }

    // MARK: 区块

    private var profileCard: some View {
        Group {
            if let child = store.current {
                HStack(spacing: 13) {
                    AvatarView(child: child, size: 54, fontSize: 26, bg: Palette.purpleSoft)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(child.name).font(.system(size: 16, weight: .bold)).foregroundColor(Palette.ink)
                        Text("\(child.sex.label) · \(GrowthMath.ageText(from: child.birthDate)) · \(GrowthMath.dateString(child.birthDate))")
                            .font(.system(size: 12.5)).foregroundColor(Palette.subtle)
                    }
                    Spacer()
                    Button("编辑") { showKidEditor = true }
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(Palette.purple)
                }
                .cardStyle()
                .padding(.horizontal, 16)
                .padding(.top, 14)
            } else {
                Button("＋ 添加宝宝档案") { showKidEditor = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(16)
            }
        }
    }

    private var statsGrid: some View {
        let records = store.state.children.reduce(0) { $0 + $1.records.count }
        let feeds = store.state.children.reduce(0) { $0 + $1.feeds.count }
        let firstDate = store.state.children.map { $0.createdAt }.min() ?? Date()
        let days = max(1, (Calendar.current.dateComponents([.day], from: firstDate, to: Date()).day ?? 0) + 1)
        let items: [(String, String)] = [
            ("\(store.state.children.count)", "宝宝"),
            ("\(records)", "生长"),
            ("\(feeds)", "喂养"),
            ("\(days)", "使用天")
        ]
        return HStack(spacing: 8) {
            ForEach(items, id: \.1) { item in
                VStack(spacing: 2) {
                    Text(item.0).font(.system(size: 18, weight: .bold)).foregroundColor(Palette.purple)
                    Text(item.1).font(.system(size: 10.5)).foregroundColor(Palette.subtle)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Palette.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.hairline, lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var aiSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "AI 助手")
            VStack(spacing: 0) {
                NavigationLink { VoiceAssistantView() } label: {
                    HStack(spacing: 10) {
                        Text("🎙️").font(.system(size: 17))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("语音助手").font(.system(size: 14)).foregroundColor(Palette.ink)
                            Text("说一句话就能记喂养、加待办、查今天的数据")
                                .font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                        }
                        Spacer()
                        Text("免费")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(Palette.purple)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Palette.purpleTint)
                            .clipShape(Capsule())
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(Palette.subtle)
                    }
                    .padding(.vertical, 9)
                }
                .buttonStyle(SoftPressStyle())
            }
            .cardStyle(padding: 14)
            .padding(.horizontal, 16)
        }
    }

    private var settingsSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "记录设置")
            VStack(spacing: 0) {
                HStack {
                    Text("体重单位").font(.system(size: 14)).foregroundColor(Palette.ink)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { store.settings.weightUnit },
                        set: { store.setWeightUnit($0) })) {
                        Text("kg").tag("kg")
                        Text("斤").tag("斤")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                .padding(.vertical, 9)
                Divider().background(Palette.hairlineSoft)

                Button { showParents = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("父母身高").font(.system(size: 14)).foregroundColor(Palette.ink)
                            Text("用于 18 岁靶身高预测").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                        }
                        Spacer()
                        Text(parentsText).font(.system(size: 13, weight: .semibold)).foregroundColor(Palette.purple)
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(Palette.subtle)
                    }
                    .padding(.vertical, 9)
                }
                .buttonStyle(SoftPressStyle())
                Divider().background(Palette.hairlineSoft)

                Toggle(isOn: Binding(
                    get: { store.settings.showFeed },
                    set: { store.setShowFeed($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("喂养模块").font(.system(size: 14)).foregroundColor(Palette.ink)
                        Text("关闭后隐藏「喂养」Tab、首页今日记录统计与喂养类快捷入口")
                            .font(.system(size: 11.5))
                            .foregroundColor(Palette.subtle)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Palette.purple)
                .padding(.vertical, 6)
                Divider().background(Palette.hairlineSoft)

                Toggle(isOn: Binding(
                    get: { store.settings.showShot },
                    set: { store.setShowShot($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("接种模块").font(.system(size: 14)).foregroundColor(Palette.ink)
                        Text("广东免疫规划 \(GrowthMath.totalDoses) 剂").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                    }
                }
                .tint(Palette.purple)
                .padding(.vertical, 6)
                Divider().background(Palette.hairlineSoft)

                Toggle(isOn: Binding(
                    get: { store.settings.showSize },
                    set: { store.setShowSize($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("鞋服尺码模块").font(.system(size: 14)).foregroundColor(Palette.ink)
                        Text("关闭后隐藏首页「鞋服尺码」入口与尺码记录（记录不会被删除）")
                            .font(.system(size: 11.5))
                            .foregroundColor(Palette.subtle)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Palette.purple)
                .padding(.vertical, 6)
                Divider().background(Palette.hairlineSoft)

                Toggle(isOn: Binding(
                    get: { store.settings.showLog == true },
                    set: { store.setShowLog($0); AppLog.isEnabled = $0 })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("运行日志").font(.system(size: 14)).foregroundColor(Palette.ink)
                        Text("独立开关，默认关。开启后记录页面加载等过程；崩溃无论开关都会记录")
                            .font(.system(size: 11.5))
                            .foregroundColor(Palette.subtle)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Palette.purple)
                .padding(.vertical, 6)
                Divider().background(Palette.hairlineSoft)

                HStack {
                    Text("外观").font(.system(size: 14)).foregroundColor(Palette.ink)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { themeValue },
                        set: { store.setDarkMode($0 == "auto" ? nil : ($0 == "dark")) })) {
                        Text("跟随系统").tag("auto")
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }
                .padding(.vertical, 9)
            }
            .cardStyle(padding: 14)
            .padding(.horizontal, 16)
        }
    }

    private var childrenSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "孩子")
            VStack(spacing: 0) {
                ForEach(store.state.children) { kid in
                    Button { store.selectChild(kid.id) } label: {
                        HStack(spacing: 10) {
                            AvatarView(child: kid, size: 28, fontSize: 19)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kid.name).font(.system(size: 14)).foregroundColor(Palette.ink)
                                Text(GrowthMath.ageText(from: kid.birthDate)).font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                            }
                            Spacer()
                            if kid.id == store.state.currentID {
                                TagView(text: "当前", tone: .ok)
                            } else {
                                Text("切换").font(.system(size: 12)).foregroundColor(Palette.purple)
                            }
                        }
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(SoftPressStyle())
                    Divider().background(Palette.hairlineSoft)
                }
                Button {
                    showKidEditor = true
                } label: {
                    Text("＋ 添加另一个孩子").font(.system(size: 13.5, weight: .semibold)).foregroundColor(Palette.purple)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 9)
                }
                .buttonStyle(SoftPressStyle())
            }
            .cardStyle(padding: 14)
            .padding(.horizontal, 16)
        }
    }

    private var dataSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "数据管理")
            VStack(spacing: 0) {
                row(title: "☁️ 配对同步", subtitle: "两台手机自动同步全部资料") {
                    showSync = true
                }
                Divider().background(Palette.hairlineSoft)
                row(title: "导出备份", subtitle: "JSON，可换手机恢复") {
                    exportJSON()
                }
                Divider().background(Palette.hairlineSoft)
                row(title: "导出 CSV", subtitle: "给医生看的表格") {
                    exportCSV()
                }
                Divider().background(Palette.hairlineSoft)
                row(title: "从备份恢复", subtitle: "选择之前导出的 JSON") {
                    showImport = true
                }
                Divider().background(Palette.hairlineSoft)
                Button { showReset = true } label: {
                    HStack {
                        Text("清空全部数据").font(.system(size: 14)).foregroundColor(Palette.bad)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(Palette.subtle)
                    }
                    .padding(.vertical, 11)
                }
                .buttonStyle(SoftPressStyle())
                Text("升级 App 直接覆盖安装即可，数据不会丢（不要先删除 App）。换手机前先「导出备份」。")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.subtle)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
            .cardStyle(padding: 14)
            .padding(.horizontal, 16)
        }
    }

    private var logSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "运行日志（排查问题）")
            VStack(spacing: 0) {
                row(title: "查看日志", subtitle: "崩溃、异常与过程记录") {
                    logText = AppLog.readAll()
                    showLogSheet = true
                }
                Divider().background(Palette.hairlineSoft)
                row(title: "导出日志", subtitle: "用分享面板发给开发者") {
                    logText = AppLog.readAll()
                    let url = AppLog.fileURL
                    if FileManager.default.fileExists(atPath: url.path) {
                        shareItem = ShareItem(url: url)
                    } else {
                        shareItem = nil
                        importMessage = "暂无日志文件，先开关一次运行日志再试"
                    }
                }
                Divider().background(Palette.hairlineSoft)
                row(title: "清空日志", subtitle: "删除本机全部日志") {
                    AppLog.clear()
                    importMessage = "日志已清空"
                }
            }
            .cardStyle(padding: 14)
            .padding(.horizontal, 16)
        }
    }

    private var aboutSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "关于")
            VStack(spacing: 0) {
                KVRow(key: "版本", value: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "-")
                Divider().background(Palette.hairlineSoft)
                KVRow(key: "数据存储", value: "本机，不上传云端")
                Divider().background(Palette.hairlineSoft)
                KVRow(key: "生长标准", value: "WHO / 中国 7 岁以下 / WS·T 423")
                Divider().background(Palette.hairlineSoft)
                KVRow(key: "接种程序", value: "广东省 · 2026 版")
                Text(Standards.disclaimer)
                    .font(.system(size: 12)).foregroundColor(Palette.subtle).lineSpacing(3).padding(.top, 10)
            }
            .cardStyle(padding: 14)
            .padding(.horizontal, 16)
        }
    }

    private func row(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14)).foregroundColor(Palette.ink)
                    Text(subtitle).font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(Palette.subtle)
            }
            .padding(.vertical, 9)
        }
        .buttonStyle(SoftPressStyle())
    }

    // MARK: 辅助

    private var parentsText: String {
        guard let f = store.settings.fatherHeight, let m = store.settings.motherHeight else { return "未填写" }
        return "\(Int(f)) / \(Int(m)) cm"
    }

    private var themeValue: String {
        guard let dark = store.settings.darkMode else { return "auto" }
        return dark ? "dark" : "light"
    }

    private func exportJSON() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("萌宝成长备份-\(GrowthMath.dateString(Date())).json")
        do {
            try store.exportJSON().data(using: .utf8)?.write(to: url)
            shareItem = ShareItem(url: url)
        } catch {
            importMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func exportCSV() {
        guard let child = store.current else {
            importMessage = "还没有孩子档案"
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(child.name)-生长记录-\(GrowthMath.dateString(Date())).csv")
        do {
            try store.exportCSV(for: child).data(using: .utf8)?.write(to: url)
            shareItem = ShareItem(url: url)
        } catch {
            importMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                try store.importJSON(text)
                importMessage = "恢复成功"
            } catch {
                importMessage = "恢复失败：\(error.localizedDescription)"
            }
        case .failure(let error):
            importMessage = "恢复失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - 父母身高

struct ParentsHeightView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var father = ""
    @State private var mother = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        numberField(title: "爸爸身高", text: $father)
                        numberField(title: "妈妈身高", text: $mother)
                    }
                    .cardStyle()

                    Button("保存") {
                        let f = Double(father)
                        let m = Double(mother)
                        if let f = f, f < 120 || f > 220 { return }
                        if let m = m, m < 120 || m > 210 { return }
                        store.setParents(father: f, mother: m)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Text("靶身高公式：男孩 (父+母+13)/2，女孩 (父+母−13)/2，误差约 ±5cm。仅用于参考，不代表最终身高。")
                        .font(.system(size: 12)).foregroundColor(Palette.subtle).lineSpacing(3)
                }
                .padding(16)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("父母身高")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .onAppear {
                if let f = store.settings.fatherHeight { father = String(format: "%.0f", f) }
                if let m = store.settings.motherHeight { mother = String(format: "%.0f", m) }
            }
        }
    }

    private func numberField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 11.5)).foregroundColor(Palette.subtle)
            HStack(spacing: 4) {
                TextField("cm", text: text).keyboardType(.numberPad).font(.system(size: 16, weight: .semibold))
                Text("cm").font(.system(size: 12.5)).foregroundColor(Palette.subtle)
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.purpleTint)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
