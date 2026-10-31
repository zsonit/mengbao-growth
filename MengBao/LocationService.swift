import Foundation
import CoreLocation

/// 轻量定位服务：只取一次当前位置，不后台常驻、不落盘。
final class LocationService: NSObject, CLLocationManagerDelegate {

    var onUpdate: ((CLLocationCoordinate2D) -> Void)?
    var onDenied: ((String) -> Void)?

    private let manager = CLLocationManager()
    private var didRequestAuth = false
    private(set) var lastCoordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorized: Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return true
        default: return false
        }
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            if !didRequestAuth {
                didRequestAuth = true
                manager.requestWhenInUseAuthorization()
            }
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            onDenied?("定位权限已关闭，可在「设置 → 隐私与安全性 → 定位服务」里打开")
        @unknown default:
            break
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            onDenied?("定位权限已关闭，可在「设置 → 隐私与安全性 → 定位服务」里打开")
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        lastCoordinate = coordinate
        onUpdate?(coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onDenied?("定位失败：\(error.localizedDescription)")
    }
}
