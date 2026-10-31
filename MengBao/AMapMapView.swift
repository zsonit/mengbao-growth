import SwiftUI
import UIKit
import CoreLocation

// MARK: - 地图上的一个门诊点

struct ClinicPin: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    let phone: String
    let distance: Int          // 米，-1 表示未知
    let lat: Double
    let lng: Double
    let online: Bool           // true = 高德在线检索结果，false = 内置离线门诊库

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var distanceText: String {
        if distance < 0 { return "距离未知" }
        if distance < 1000 { return "\(distance) m" }
        return String(format: "%.1f km", Double(distance) / 1000.0)
    }

    init(name: String, address: String, phone: String, distance: Int, lat: Double, lng: Double, online: Bool) {
        self.name = name
        self.address = address
        self.phone = phone
        self.distance = distance
        self.lat = lat
        self.lng = lng
        self.online = online
        self.id = "\(name)@\(String(format: "%.5f", lat)),\(String(format: "%.5f", lng))"
    }
}

// MARK: - 高德地图 SwiftUI 封装

struct AMapMapView: UIViewRepresentable {

    var pins: [ClinicPin]
    var focus: CLLocationCoordinate2D?
    var focusID: String?
    var showsUserLocation: Bool = true

    var onTapPin: (ClinicPin) -> Void = { _ in }
    var onMapError: (String) -> Void = { _ in }

    func makeUIView(context: Context) -> MAMapView {
        let map = MAMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = showsUserLocation
        map.zoomLevel = 12.5
        return map
    }

    func updateUIView(_ map: MAMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncAnnotations(on: map, pins: pins)

        if let focus = focus {
            let key = String(format: "%.5f,%.5f", focus.latitude, focus.longitude)
            if context.coordinator.lastFocusKey != key {
                context.coordinator.lastFocusKey = key
                map.setCenter(focus, animated: true)
                if map.zoomLevel < 11 {
                    map.zoomLevel = 14
                }
            }
        }

        context.coordinator.select(id: focusID, on: map)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, MAMapViewDelegate {
        var parent: AMapMapView
        var lastFocusKey: String = ""
        private var lastSignature: String = ""

        init(_ parent: AMapMapView) {
            self.parent = parent
        }

        func syncAnnotations(on map: MAMapView, pins: [ClinicPin]) {
            let signature = pins.map { $0.id }.joined(separator: "|")
            if signature == lastSignature { return }
            lastSignature = signature

            let existing = (map.annotations as? [MAPointAnnotation]) ?? []
            if !existing.isEmpty {
                map.removeAnnotations(existing)
            }

            let annotations: [MAPointAnnotation] = pins.map { pin in
                let annotation = MAPointAnnotation()
                annotation.coordinate = pin.coordinate
                annotation.title = pin.name
                annotation.subtitle = pin.address
                return annotation
            }
            if !annotations.isEmpty {
                map.addAnnotations(annotations)
            }
        }

        func select(id: String?, on map: MAMapView) {
            guard let id = id,
                  let pin = parent.pins.first(where: { $0.id == id }),
                  let annotations = map.annotations as? [MAPointAnnotation]
            else { return }

            let target = annotations.first { annotation in
                abs(annotation.coordinate.latitude - pin.lat) < 1e-6
                    && abs(annotation.coordinate.longitude - pin.lng) < 1e-6
            }
            if let target = target {
                map.selectAnnotation(target, animated: true)
            }
        }

        // MARK: MAMapViewDelegate

        func mapView(_ mapView: MAMapView!, viewFor annotation: MAAnnotation!) -> MAAnnotationView! {
            guard annotation is MAPointAnnotation else { return nil }

            let identifier = "mengbao.clinic"
            if let reused = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) {
                reused.annotation = annotation
                return reused
            }

            let view = MAPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.canShowCallout = true
            view.animatesDrop = false
            view.pinColor = .red
            return view
        }

        func mapView(_ mapView: MAMapView!, didSelect view: MAAnnotationView!) {
            guard let annotation = view.annotation, annotation is MAPointAnnotation else { return }
            let coordinate = annotation.coordinate
            if let pin = parent.pins.first(where: {
                abs($0.lat - coordinate.latitude) < 1e-5 && abs($0.lng - coordinate.longitude) < 1e-5
            }) {
                parent.onTapPin(pin)
            }
        }

        func mapViewDidFailLoadingMap(_ mapView: MAMapView!, withError error: Error!) {
            parent.onMapError(error?.localizedDescription ?? "地图加载失败")
        }
    }
}
