import Foundation
import UIKit
import CoreLocation

/// 高德地图统一配置。
/// Key 从 Info.plist 读取（project.yml 的 info.properties），换 Key 不必改代码。
enum MapConfig {

    /// iOS 平台 Key：地图渲染 + 定位 + 周边搜索（已按 Bundle ID 绑定）
    static let iosKey: String = (Bundle.main.object(forInfoDictionaryKey: "AMapIOSKey") as? String) ?? ""

    /// Web 端（JS API）Key：仅用于网页版地图，原生 App 内不调用（平台类型不匹配会被拒绝）
    static let webKey: String = (Bundle.main.object(forInfoDictionaryKey: "AMapWebKey") as? String) ?? ""

    static let appName = "萌宝成长"

    static var isConfigured: Bool {
        !iosKey.isEmpty && !iosKey.hasPrefix("$(")
    }

    private static var bootstrapped = false

    /// 必须在任何高德 SDK 类实例化之前调用
    static func bootstrap() {
        guard !bootstrapped, isConfigured else { return }
        bootstrapped = true

        AMapServices.shared()?.apiKey = iosKey
        AMapServices.shared()?.enableHTTPS = true
        // 高德 8.1.0+ 隐私合规接口（在 MAMapView 类上），缺失会导致 SDK 初始化异常、地图不出图
        MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        MAMapView.updatePrivacyAgree(.didAgree)
    }

    // MARK: - 导航

    /// 高德 App 的 URL Scheme（未安装则回落网页版）
    static func schemeURL(lat: Double, lng: Double, name: String, navigate: Bool) -> URL? {
        let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let app = appName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "mengbao"
        if navigate {
            return URL(string: "iosamap://path?sourceApplication=\(app)&dlat=\(lat)&dlon=\(lng)&dname=\(enc)&dev=0&t=0")
        }
        return URL(string: "iosamap://viewMap?sourceApplication=\(app)&poiname=\(enc)&lat=\(lat)&lon=\(lng)&dev=0")
    }

    /// 高德网页版（H5 唤起）
    static func webURL(lat: Double, lng: Double, name: String, navigate: Bool) -> URL? {
        let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let app = appName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "mengbao"
        if navigate {
            return URL(string: "https://uri.amap.com/navigation?to=\(lng),\(lat),\(enc)&mode=car&policy=1&src=\(app)&coordinate=gaode&callnative=1")
        }
        return URL(string: "https://uri.amap.com/marker?position=\(lng),\(lat)&name=\(enc)&src=\(app)&coordinate=gaode&callnative=1")
    }

    /// 打开高德导航：装了高德就跳 App，没装就走网页
    static func openNavigation(lat: Double, lng: Double, name: String) {
        if let url = schemeURL(lat: lat, lng: lng, name: name, navigate: true),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return
        }
        if let url = webURL(lat: lat, lng: lng, name: name, navigate: true) {
            UIApplication.shared.open(url)
        }
    }

    /// 在地图上查看（不导航）
    static func openMap(lat: Double, lng: Double, name: String) {
        if let url = schemeURL(lat: lat, lng: lng, name: name, navigate: false),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return
        }
        if let url = webURL(lat: lat, lng: lng, name: name, navigate: false) {
            UIApplication.shared.open(url)
        }
    }
}
