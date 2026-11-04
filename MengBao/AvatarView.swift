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

    /// 把照片裁成正方形、缩到 512px 存为 JPEG，返回保存路径
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
        let url = Self.avatarFileURL(for: id)
        guard let data = square.jpegData(compressionQuality: 0.88) else { return nil }
        do {
            try data.write(to: url)
            avatarPath = "avatars/\(id.uuidString).jpg"
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
