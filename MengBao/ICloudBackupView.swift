import SwiftUI
import UniformTypeIdentifiers

// MARK: - iCloud 备份页

struct ICloudBackupView: View {
    @ObservedObject private var backup = BackupManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var files: [BackupFile] = []
    @State private var picking = false
    @State private var confirmRestore: BackupFile?
    @State private var confirmDelete: BackupFile?
    @State private var busy = false
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    statusCard
                    actionCard
                    filesCard
                    notesCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("iCloud 备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
        .onAppear { refresh() }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    try backup.setFolder(url)
                    refresh()
                    show("已连接到「\(url.lastPathComponent)」")
                } catch {
                    show("选择失败：\(error.localizedDescription)")
                }
            case .failure(let error):
                show("选择失败：\(error.localizedDescription)")
            }
        }
        .alert("恢复这份备份？", isPresented: Binding(
            get: { confirmRestore != nil },
            set: { if !$0 { confirmRestore = nil } })) {
            Button("取消", role: .cancel) { confirmRestore = nil }
            Button("恢复", role: .destructive) { doRestore() }
        } message: {
            if let f = confirmRestore {
                Text("将用 \(BackupManager.displayFormatter.string(from: f.date)) 的备份覆盖当前全部数据（\(f.childCount) 个宝宝、\(f.recordCount) 条记录）。恢复前会先自动备份当前数据。")
            }
        }
        .alert("删除这份备份？", isPresented: Binding(
            get: { confirmDelete != nil },
            set: { if !$0 { confirmDelete = nil } })) {
            Button("取消", role: .cancel) { confirmDelete = nil }
            Button("删除", role: .destructive) {
                if let f = confirmDelete { backup.delete(f) }
                confirmDelete = nil
                refresh()
                show("已删除")
            }
        } message: {
            Text(confirmDelete?.id ?? "")
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.75)))
                    .padding(.bottom, 40)
                    .transition(.opacity)
            }
        }
    }

    // MARK: 状态

    private var statusCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(backup.hasFolder ? "☁️" : "📁").font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(backup.folderName ?? "还没有选择备份文件夹")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Palette.ink)
                        Text(backup.hasFolder ? "备份会自动写进这个文件夹" : "选一个 iCloud 云盘文件夹，重装或换手机后能找回来")
                            .font(.system(size: 11.5))
                            .foregroundColor(Palette.subtle)
                    }
                    Spacer()
                }

                Divider().background(Palette.hairlineSoft)

                HStack {
                    Text("上次备份").font(.system(size: 13)).foregroundColor(Palette.ink2)
                    Spacer()
                    Text(lastBackupText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(backup.lastBackupAt == nil ? Palette.subtle : Palette.ink)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("自动备份").font(.system(size: 13.5)).foregroundColor(Palette.ink)
                        Text("改动后自动备份，最多保留 \(20) 份")
                            .font(.system(size: 11))
                            .foregroundColor(Palette.subtle)
                    }
                    Spacer()
                    Toggle("", isOn: $backup.autoOn)
                        .labelsHidden()
                        .tint(Palette.purple)
                        .disabled(!backup.hasFolder)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var lastBackupText: String {
        guard let at = backup.lastBackupAt else { return "还没备份过" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = Calendar.current.isDateInToday(at) ? "'今天' HH:mm" : "M月d日 HH:mm"
        return f.string(from: at)
    }

    // MARK: 操作

    private var actionCard: some View {
        card {
            VStack(spacing: 10) {
                Button {
                    if backup.hasFolder {
                        busy = true
                        let ok = backup.backupNow()
                        busy = false
                        refresh()
                        show(ok ? "备份完成" : (backup.message ?? "备份失败"))
                    } else {
                        picking = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        if busy { ProgressView().tint(.white) }
                        Text(backup.hasFolder ? "立即备份" : "选择备份文件夹")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                if backup.hasFolder {
                    Button("更换文件夹") { picking = true }
                        .buttonStyle(PrimaryButtonStyle(filled: false))
                }
            }
        }
    }

    // MARK: 备份列表

    private var filesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("备份记录").font(.system(size: 13, weight: .bold)).foregroundColor(Palette.ink)
                    Spacer()
                    Text("\(files.count) 份").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                }
                .padding(.bottom, 8)

                if files.isEmpty {
                    Text(backup.hasFolder ? "还没有备份，点上面「立即备份」" : "选好文件夹后就会显示备份")
                        .font(.system(size: 12))
                        .foregroundColor(Palette.subtle)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(files.prefix(10))) { f in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(BackupManager.displayFormatter.string(from: f.date))
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundColor(Palette.ink)
                                Text("\(f.childCount) 个宝宝 · \(f.recordCount) 条记录 · \(BackupManager.sizeText(f.size))")
                                    .font(.system(size: 11))
                                    .foregroundColor(Palette.subtle)
                            }
                            Spacer(minLength: 6)
                            Button("恢复") { confirmRestore = f }
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(Palette.purple)
                        }
                        .padding(.vertical, 8)
                        if f.id != files.prefix(10).last?.id {
                            Divider().background(Palette.hairlineSoft)
                        }
                    }
                    if files.count > 10 {
                        Text("只显示最近 10 份，文件夹里共 \(files.count) 份")
                            .font(.system(size: 11))
                            .foregroundColor(Palette.subtle)
                            .padding(.top, 6)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var notesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text("说明").font(.system(size: 13, weight: .bold)).foregroundColor(Palette.ink)
                Text("① 建议先在「文件」App 的 iCloud 云盘里建一个「萌宝成长」文件夹，再回来选它；\n② 备份是 JSON 明文文件，里面是宝宝的身高体重和记录，别随意外发；\n③ 这个方案不依赖 iCloud 权限，侧载安装也能正常用；\n④ 换手机时：新手机装好 App → 进这里选同一个 iCloud 文件夹 → 点最早/最新那份「恢复」。")
                    .font(.system(size: 12.5))
                    .foregroundColor(Palette.ink2)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: 辅助

    private func refresh() {
        files = backup.list()
    }

    private func doRestore() {
        guard let f = confirmRestore else { return }
        confirmRestore = nil
        busy = true
        // 恢复前先把当前数据存一份，避免点错了回不来
        if backup.hasFolder { _ = backup.backupNow() }
        do {
            try backup.restore(f)
            refresh()
            show("恢复成功")
        } catch {
            show("恢复失败：\(error.localizedDescription)")
        }
        busy = false
    }

    private func show(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { if toast == text { toast = nil } }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
