import SwiftUI
import WebKit
import CoreLocation
import UIKit

/// 粤苗（广东省疾控中心）官方「接种门诊」页面
/// https://ymapp.cdcp.org.cn/nipisgd/parent-app/index.html#/pages/patient/listNoNav
struct YamiaoView: View {
    @State private var reloadToken = 0
    @State private var loading = true
    @State private var failed = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text("粤苗官方 · 接种门诊")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.ink)
                Spacer()
                Button {
                    loading = true
                    failed = false
                    reloadToken += 1
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Palette.ink)
                }
                .buttonStyle(SoftPressStyle())
                Button {
                    if let url = URL(string: YamiaoWebView.url.absoluteString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Image(systemName: "safari")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Palette.ink)
                }
                .buttonStyle(SoftPressStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Rectangle().fill(Palette.hairline).frame(height: 0.5)

            ZStack {
                YamiaoWebView(url: YamiaoWebView.url, reloadToken: reloadToken,
                              onLoading: { loading = $0 }, onFailure: { failed = $0 })
                    .ignoresSafeArea(edges: .bottom)

                if loading && !failed {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("正在加载粤苗门诊查询…")
                            .font(.system(size: 13))
                            .foregroundColor(Palette.subtle)
                    }
                }

                if failed {
                    VStack(spacing: 10) {
                        Text("页面加载失败")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Palette.ink)
                        Text("粤苗是广东省疾控中心的在线服务，需要网络。请检查网络后重试，或点右上角 Safari 图标在浏览器打开。")
                            .font(.system(size: 12.5))
                            .foregroundColor(Palette.subtle)
                            .multilineTextAlignment(.center)
                        Button {
                            loading = true
                            failed = false
                            reloadToken += 1
                        } label: {
                            Text("重试")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Palette.purpleDeep))
                        }
                        .buttonStyle(SoftPressStyle())
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 32)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Palette.background)
        .navigationTitle("接种门诊")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - WebView（含定位桥接）

struct YamiaoWebView: UIViewRepresentable {
    static let urlString = "https://ymapp.cdcp.org.cn/nipisgd/parent-app/index.html#/pages/patient/listNoNav"
    static var url: URL { URL(string: urlString)! }

    let url: URL
    let reloadToken: Int
    let onLoading: (Bool) -> Void
    let onFailure: (Bool) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(GeoBridge.shared, name: "ymGeo")
        config.userContentController.addUserScript(WKUserScript(
            source: GeoBridge.injectedJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        config.allowsInlineMediaPlayback = true

        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.backgroundColor = .systemBackground
        view.scrollView.contentInsetAdjustmentBehavior = .automatic
        YamiaoWebViewStore.current = view
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        if view.tag != reloadToken {
            view.tag = reloadToken
            if reloadToken > 0 {
                onLoading(true)
                onFailure(false)
                view.reload()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: YamiaoWebView
        init(_ parent: YamiaoWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.onLoading(false)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.onLoading(false)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.onLoading(false)
            parent.onFailure(true)
        }

        /// 高德 / 百度 / 电话等外链交给系统打开
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               let scheme = url.scheme?.lowercased(),
               ["tel", "mailto", "sms", "iosamap", "amapuri", "baidumap", "qqmap", "weixin"].contains(scheme) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

// MARK: - 定位桥接（WKWebView 不支持网页 Geolocation API，这里用 CoreLocation 补上）

final class GeoBridge: NSObject, WKScriptMessageHandler, CLLocationManagerDelegate {
    static let shared = GeoBridge()

    private let manager = CLLocationManager()
    private var pendingIds: [Int] = []
    private var lastLocation: CLLocation?

    static let injectedJS = """
    (function(){
      if (window.__ymGeoPatched) return;
      window.__ymGeoPatched = true;
      var seq = 0, cbs = {};
      var post = function(id){ window.webkit.messageHandlers.ymGeo.postMessage({id: id}); };
      navigator.geolocation.getCurrentPosition = function(success, error, options){
        var id = ++seq; cbs[id] = {s: success, e: error}; post(id);
      };
      navigator.geolocation.watchPosition = function(success, error, options){
        var id = ++seq; cbs[id] = {s: success, e: error}; post(id); return id;
      };
      navigator.geolocation.clearWatch = function(){};
      window.__ymGeoResolve = function(id, lat, lng, acc){
        var cb = cbs[id]; if (!cb) return; delete cbs[id];
        cb.s({ coords: { latitude: lat, longitude: lng, accuracy: acc,
                         altitude: null, altitudeAccuracy: null, heading: null, speed: null },
               timestamp: Date.now() });
      };
      window.__ymGeoReject = function(id, code, msg){
        var cb = cbs[id]; if (!cb) return; delete cbs[id];
        if (cb.e) cb.e({ code: code || 1, message: msg || '定位失败', PERMISSION_DENIED: 1, POSITION_UNAVAILABLE: 2 });
      };
    })();
    """

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "ymGeo", let body = message.body as? [String: Any],
              let id = body["id"] as? Int else { return }
        pendingIds.append(id)

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            rejectAll(code: 1, msg: "定位权限已关闭，可在「设置 → 隐私与安全性 → 定位服务」里打开")
        default:
            if let last = lastLocation {
                resolveAll(last)
            } else {
                manager.requestLocation()
            }
        }
    }

    private func resolveAll(_ location: CLLocation) {
        let ids = pendingIds
        pendingIds.removeAll()
        let js = "window.__ymGeoResolve && " + ids.map {
            String(format: "__ymGeoResolve(%d, %.6f, %.6f, %.0f)", $0, location.coordinate.latitude, location.coordinate.longitude, max(location.horizontalAccuracy, 30))
        }.joined(separator: " && ") + ";"
        topWebview?.evaluateJavaScript(js, completionHandler: nil)
    }

    private func rejectAll(code: Int, msg: String) {
        let ids = pendingIds
        pendingIds.removeAll()
        let escaped = msg.replacingOccurrences(of: "'", with: "\\'")
        let js = "window.__ymGeoReject && " + ids.map {
            "__ymGeoReject(\($0), \(code), '\(escaped)')"
        }.joined(separator: " && ") + ";"
        topWebview?.evaluateJavaScript(js, completionHandler: nil)
    }

    private var topWebview: WKWebView? {
        // 单例桥没有直接持有 webview，改用 UIApplication 遍历开销太大；用弱引用注册更稳。
        YamiaoWebViewStore.current
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastLocation = loc
        resolveAll(loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        rejectAll(code: 2, msg: "定位失败，请稍后重试")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if !pendingIds.isEmpty { manager.requestLocation() }
        case .denied, .restricted:
            rejectAll(code: 1, msg: "定位权限已关闭，可在「设置 → 隐私与安全性 → 定位服务」里打开")
        default:
            break
        }
    }
}

/// 让桥能找到当前 WebView（全局最多一个粤苗页）
enum YamiaoWebViewStore {
    static weak var current: WKWebView?
}
