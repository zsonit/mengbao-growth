import SwiftUI
import UIKit

// MARK: - 头像照片存取

extension Child {
    static func avatarFileURL(for id: UUID) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("avatars/\(id.uuidString).jpg")
    }

    var avatarImage: UIImage? {
        guard let path = avatarPath else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return UIImage(contentsOfFile: docs.appendingPathComponent(path).path)
    }

    /// 把照片缩到 512px 存为 JPEG。文件名每次唯一（时间戳），并在保存时删除旧文件：
    /// 避免固定路径下 UIImage(contentsOfFile:) 的系统缓存导致「更换照片后界面不刷新」
    @discardableResult
    mutating func saveAvatarPhoto(_ image: UIImage) -> URL? {
        let src = image.normalized()
        let side = min(src.size.width, src.size.height)
        guard side > 0, src.size.width > 0, src.size.height > 0 else { return nil }
        let scale = 512.0 / side
        let x = (src.size.width - side) / 2
        let y = (src.size.height - side) / 2

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let square = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512), format: format).image { _ in
            src.draw(in: CGRect(x: -x * scale, y: -y * scale,
                                width: src.size.width * scale,
                                height: src.size.height * scale))
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // 删除旧照片文件
        if let old = avatarPath {
            try? FileManager.default.removeItem(at: docs.appendingPathComponent(old))
        }
        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        let rel = "avatars/\(id.uuidString)-\(stamp).jpg"
        let url = docs.appendingPathComponent(rel)
        guard let data = square.jpegData(compressionQuality: 0.88) else { return nil }
        do {
            try data.write(to: url)
            avatarPath = rel
            return url
        } catch { return nil }
    }

    func removeAvatarPhoto() {
        guard let path = avatarPath else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: docs.appendingPathComponent(path))
    }
}

private extension UIImage {
    /// 统一图片方向，便于绘制
    func normalized() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - 头像方形裁剪（双指缩放 + 拖动调整角度）

/// 用于 sheet(item:) 的包装
struct CropImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// 选照片后弹出：方框内双指缩放、拖动平移，确认后按方框可视区域裁剪出正方形头像
struct AvatarCropView: View {
    let source: UIImage
    let onConfirm: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let boxSide: CGFloat = 280

    var body: some View {
        VStack(spacing: 18) {
            Text("双指缩放、拖动图片，调整好角度后保存")
                .font(.system(size: 12.5)).foregroundColor(Palette.subtle)

            ZStack {
                Rectangle().fill(Color.black.opacity(0.82))
                Image(uiImage: source.normalized())
                    .resizable()
                    .scaledToFill()
                    .frame(width: boxSide, height: boxSide)
                    .scaleEffect(scale)
                    .offset(offset)
                // 四角参考线
                CropCornerLines(boxSide: boxSide)
            }
            .frame(width: boxSide, height: boxSide)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .gesture(dragGesture.simultaneously(with: pinchGesture))

            HStack(spacing: 14) {
                Button("取消") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle(filled: false))
                Button("✂️ 就选这样") { confirm() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Palette.background.ignoresSafeArea())
    }

    /// 基准显示尺寸（scale = 1 时按 aspect-fill 铺满方框）
    private func baseDisplaySize() -> CGSize {
        let s = source.normalized().size
        let k = max(boxSide / s.width, boxSide / s.height)
        return CGSize(width: s.width * k, height: s.height * k)
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { v in
                scale = min(max(lastScale * v, 1), 8)
            }
            .onEnded { _ in
                lastScale = scale
                clampOffset()
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                offset = CGSize(width: lastOffset.width + v.translation.width,
                                height: lastOffset.height + v.translation.height)
            }
            .onEnded { _ in clampOffset() }
    }

    /// 限制拖动范围：保证图片始终铺满方框，不露黑边（scale=1 时图片正好铺满，不允许拖动）
    private func clampOffset() {
        let base = baseDisplaySize()
        let maxX = max(0, (base.width * scale - boxSide) / 2)
        let maxY = max(0, (base.height * scale - boxSide) / 2)
        offset = CGSize(width: min(max(offset.width, -maxX), maxX),
                        height: min(max(offset.height, -maxY), maxY))
        lastOffset = offset
    }

    /// 按方框可视区域裁剪源图，再缩放为 512×512
    private func croppedImage() -> UIImage {
        let img = source.normalized()
        let s = img.size
        let k = max(boxSide / s.width, boxSide / s.height)
        let total = k * scale
        let w = s.width * total
        let h = s.height * total
        // 图片左上角在方框坐标系中的位置
        let tlX = boxSide / 2 - w / 2 + offset.width
        let tlY = boxSide / 2 - h / 2 + offset.height
        // 方框对应到源图（点）坐标
        var cropX = -tlX / total
        var cropY = -tlY / total
        let cropW = boxSide / total
        let cropH = boxSide / total
        cropX = min(max(cropX, 0), max(0, s.width - cropW))
        cropY = min(max(cropY, 0), max(0, s.height - cropH))

        let px = CGRect(x: cropX * img.scale, y: cropY * img.scale,
                        width: cropW * img.scale, height: cropH * img.scale)
        var result = img
        if let cg = img.cgImage, let cut = cg.cropping(to: px) {
            result = UIImage(cgImage: cut)
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512), format: format).image { _ in
            result.draw(in: CGRect(x: 0, y: 0, width: 512, height: 512))
        }
    }

    private func confirm() {
        onConfirm(croppedImage())
        dismiss()
    }
}

/// 裁剪框四角参考线
private struct CropCornerLines: View {
    let boxSide: CGFloat
    private let len: CGFloat = 26
    private let inset: CGFloat = 10

    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            let c = Color.white.opacity(0.9)
            let pts: [(CGPoint, CGPoint)] = [
                (CGPoint(x: inset, y: inset), CGPoint(x: inset + len, y: inset)),
                (CGPoint(x: inset, y: inset), CGPoint(x: inset, y: inset + len)),
                (CGPoint(x: size.width - inset, y: inset), CGPoint(x: size.width - inset - len, y: inset)),
                (CGPoint(x: size.width - inset, y: inset), CGPoint(x: size.width - inset, y: inset + len)),
                (CGPoint(x: inset, y: size.height - inset), CGPoint(x: inset + len, y: size.height - inset)),
                (CGPoint(x: inset, y: size.height - inset), CGPoint(x: inset, y: size.height - inset - len)),
                (CGPoint(x: size.width - inset, y: size.height - inset), CGPoint(x: size.width - inset - len, y: size.height - inset)),
                (CGPoint(x: size.width - inset, y: size.height - inset), CGPoint(x: size.width - inset, y: size.height - inset - len)),
            ]
            for (a, b) in pts { p.move(to: a); p.addLine(to: b) }
            ctx.stroke(p, with: .color(c), lineWidth: 2)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 头像视图

/// 有自定义照片显示照片，否则显示 emoji（样式与旧版一致）
struct AvatarView: View {
    let child: Child?
    var size: CGFloat = 50
    var fontSize: CGFloat = 26
    var bg: Color = Palette.pinkBg
    /// 传值则显示为圆角方形（如成长页大头像），nil 为圆形
    var cornerRadius: CGFloat? = nil

    private var shape: AnyShape {
        if let cornerRadius {
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        return AnyShape(Circle())
    }

    var body: some View {
        if let child, let img = child.avatarImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(shape)
        } else {
            Text(child?.displayAvatar ?? "👶")
                .font(.system(size: fontSize))
                .frame(width: size, height: size)
                .background(shape.fill(bg))
        }
    }
}
