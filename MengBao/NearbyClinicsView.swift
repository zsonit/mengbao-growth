import SwiftUI
import UIKit
import CoreLocation

// MARK: - 数据模型

final class NearbyClinicsModel: NSObject, ObservableObject, AMapSearchDelegate {

    @Published var pins: [ClinicPin] = []
    @Published var focus: CLLocationCoordinate2D?
    @Published var selectedID: String?
    @Published var message: String = "正在定位…"
    @Published var isLoading = false
    @Published var usingOffline = false
    @Published var mapErrorText: String?

    private let location = LocationService()
    private var searchAPI: AMapSearchAPI?
    private var center: CLLocationCoordinate2D?
    private var keyword = "预防接种门诊"
    private var radius = 5000
    private var timeoutWork: DispatchWorkItem?
    private var didStart = false

    override init() {
        super.init()

        location.onUpdate = { [weak self] coordinate in
            guard let self = self else { return }
            self.center = coordinate
            self.focus = coordinate
            self.runSearch()
        }
        location.onDenied = { [weak self] reason in
            guard let self = self else { return }
            self.fallbackOffline(reason: reason)
        }
    }

    // MARK: 对外

    func onAppear() {
        guard !didStart else { return }
        didStart = true
        location.start()
    }

    func locateAgain() {
        mapErrorText = nil
        message = "正在定位…"
        location.start()
    }

    func search(keyword: String, radius: Int) {
        self.keyword = keyword
        self.radius = radius
        runSearch()
    }

    func select(_ pin: ClinicPin) {
        selectedID = pin.id
        focus = pin.coordinate
    }

    // MARK: 搜索

    private func runSearch() {
        guard let center = center else {
            message = "等待定位结果…"
            return
        }

        isLoading = true
        usingOffline = false
        message = "正在搜索附近的「\(keyword)」…"

        guard MapConfig.isConfigured else {
            fallbackOffline(reason: "未配置高德 Key")
            return
        }

        if searchAPI == nil {
            let api = AMapSearchAPI()
            api?.delegate = self
            searchAPI = api
        }

        let request = AMapPOIAroundSearchRequest()
        request.location = AMapGeoPoint.location(withLatitude: CGFloat(center.latitude),
                                                longitude: CGFloat(center.longitude))
        request.keywords = keyword
        request.radius = radius
        request.offset = 25
        request.page = 1
        request.sortrule = 0
        request.requireExtension = false
        searchAPI?.aMapPOIAroundSearch(request)

        timeoutWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.isLoading else { return }
            self.fallbackOffline(reason: "搜索超时")
        }
        timeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }

    private func fallbackOffline(reason: String) {
        timeoutWork?.cancel()

        let anchor = center
        var list: [ClinicPin] = Standards.clinics.map { clinic in
            var distance = -1
            if let anchor = anchor {
                let from = CLLocation(latitude: anchor.latitude, longitude: anchor.longitude)
                let to = CLLocation(latitude: clinic.lat, longitude: clinic.lng)
                distance = Int(from.distance(from: to))
            }
            return ClinicPin(name: clinic.name,
                             address: clinic.address,
                             phone: clinic.phone,
                             distance: distance,
                             lat: clinic.lat,
                             lng: clinic.lng,
                             online: false)
        }

        list.sort { lhs, rhs in
            let a = lhs.distance < 0 ? Int.max : lhs.distance
            let b = rhs.distance < 0 ? Int.max : rhs.distance
            return a < b
        }
        let top = Array(list.prefix(12))

        DispatchQueue.main.async {
            self.pins = top
            self.isLoading = false
            self.usingOffline = true
            self.selectedID = top.first?.id
            if let first = top.first, self.center == nil {
                self.focus = first.coordinate
            }
            self.message = "\(reason)，已切换到内置门诊库（\(top.count) 家，距离为直线估算）"
        }
    }

    // MARK: AMapSearchDelegate

    func onPOISearchDone(_ request: AMapPOISearchBaseRequest!, response: AMapPOISearchResponse!) {
        timeoutWork?.cancel()

        guard let response = response,
              let pois = response.pois as? [AMapPOI],
              !pois.isEmpty
        else {
            fallbackOffline(reason: "附近没有搜到门诊")
            return
        }

        var mapped: [ClinicPin] = []
        for poi in pois {
            guard let location = poi.location else { continue }
            mapped.append(ClinicPin(name: poi.name ?? "接种门诊",
                                    address: poi.address ?? "",
                                    phone: poi.tel ?? "",
                                    distance: Int(poi.distance),
                                    lat: Double(location.latitude),
                                    lng: Double(location.longitude),
                                    online: true))
        }

        guard !mapped.isEmpty else {
            fallbackOffline(reason: "搜索结果为空")
            return
        }

        DispatchQueue.main.async {
            self.pins = mapped
            self.isLoading = false
            self.usingOffline = false
            self.selectedID = mapped.first?.id
            self.message = "共 \(mapped.count) 家 · 数据来自高德地图，出发前请电话确认"
        }
    }

    func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
        if let work = timeoutWork, !work.isCancelled {
            work.cancel()
        }
        fallbackOffline(reason: "高德检索失败")
    }
}

// MARK: - 附近门诊地图页

struct NearbyClinicsView: View {

    @StateObject private var model = NearbyClinicsModel()
    @Environment(\.dismiss) private var dismiss

    @State private var keyword = "预防接种门诊"
    @State private var radius = 5000

    private let radiusOptions: [(String, Int)] = [
        ("1 公里", 1000), ("3 公里", 3000), ("5 公里", 5000), ("10 公里", 10000)
    ]

    var body: some View {
        ZStack(alignment: .top) {
            AMapMapView(pins: model.pins,
                        focus: model.focus,
                        focusID: model.selectedID,
                        onTapPin: { model.select($0) },
                        onMapError: { model.mapErrorText = $0 })
                .ignoresSafeArea()

            VStack(spacing: 0) {
                searchBar
                Spacer(minLength: 0)
                if !model.pins.isEmpty {
                    resultStrip
                }
                statusBar
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            model.onAppear()
            model.search(keyword: keyword, radius: radius)
        }
    }

    // MARK: 顶部搜索

    private var searchBar: some View {
        VStack(spacing: 9) {
            HStack(spacing: 9) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Palette.ink)
                        .frame(width: 36, height: 36)
                        .background(Palette.card)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(Palette.subtle)
                    TextField("搜索接种门诊 / 医院 / 卫生服务中心", text: $keyword)
                        .font(.system(size: 13.5))
                        .submitLabel(.search)
                        .onSubmit { model.search(keyword: keyword, radius: radius) }
                    if !keyword.isEmpty {
                        Button { keyword = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Palette.subtle)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Palette.card)
                .clipShape(Capsule())

                Button { model.locateAgain() } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Palette.purple)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 7) {
                ForEach(radiusOptions, id: \.1) { option in
                    Button {
                        radius = option.1
                        model.search(keyword: keyword, radius: option.1)
                    } label: {
                        Text(option.0)
                            .font(.system(size: 11.5, weight: radius == option.1 ? .semibold : .regular))
                            .foregroundColor(radius == option.1 ? .white : Palette.ink2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(radius == option.1 ? Palette.purple : Palette.card)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
    }

    // MARK: 底部结果

    private var resultStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(model.pins) { pin in
                    resultCard(pin)
                        .onTapGesture { model.select(pin) }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
        }
        .padding(.bottom, 4)
    }

    private func resultCard(_ pin: ClinicPin) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(pin.online ? "🏥" : "💉")
                    .font(.system(size: 12))
                Text(pin.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
            }

            Text(pin.address.isEmpty ? "地址见导航" : pin.address)
                .font(.system(size: 11))
                .foregroundColor(Palette.subtle)
                .lineLimit(2)
                .frame(width: 178, height: 28, alignment: .topLeading)

            HStack(spacing: 6) {
                Text(pin.distanceText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Palette.purple)
                Spacer(minLength: 0)
                Button {
                    MapConfig.openNavigation(lat: pin.lat, lng: pin.lng, name: pin.name)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 9))
                        Text("导航")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Palette.purple)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(width: 178)
        }
        .padding(11)
        .frame(width: 200, alignment: .leading)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(model.selectedID == pin.id ? Palette.purple : Palette.hairline,
                        lineWidth: model.selectedID == pin.id ? 1.8 : 1)
        )
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if model.isLoading {
                    ProgressView().scaleEffect(0.55).frame(width: 12, height: 12)
                }
                Text(model.message)
                    .font(.system(size: 11))
                    .foregroundColor(Palette.subtle)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if model.usingOffline {
                    Text("离线")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(Palette.warn)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Palette.warnBg)
                        .clipShape(Capsule())
                }
            }

            if let error = model.mapErrorText {
                Text("地图加载失败：\(error)。请检查高德 Key 是否与 Bundle ID（com.zsonit.mengbao）绑定。")
                    .font(.system(size: 10.5))
                    .foregroundColor(Palette.bad)
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }
}
