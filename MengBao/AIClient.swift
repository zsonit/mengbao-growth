import Foundation

// MARK: - 免密钥大模型客户端
//
// 走 WorkBuddy 云服务的 /.cloud/llm 通道：家长不需要填任何 API Key，也不额外花钱。
// 接口只支持流式（SSE），所以"要完整结果"的场景也是在流里收集完再用。

struct AIModel: Identifiable, Decodable, Equatable {
    let id: String
    let name: String?
    let enabled: Bool?
    let supportsImages: Bool?

    var label: String { (name?.isEmpty == false) ? name! : id }
    var usable: Bool { enabled ?? true }

    /// 界面上只展示这几种常用档位，避免一次列出 30 多个模型
    static func quick(_ list: [AIModel]) -> [AIModel] {
        let picked = ["glm-5.3-flash", "auto", "deepseek-v4-flash", "glm-5.3", "hunyuan-chat"]
        var out = list.filter { picked.contains($0.id) && $0.usable }
        out.sort { a, b in
            (picked.firstIndex(of: a.id) ?? 99) < (picked.firstIndex(of: b.id) ?? 99)
        }
        if out.isEmpty { out = Array(list.filter(\.usable).prefix(3)) }
        return out
    }
}

enum AIError: LocalizedError {
    case network(String)
    case auth
    case quota(String)
    case http(Int)
    case empty

    var errorDescription: String? {
        switch self {
        case .network(let m): return m.isEmpty ? "网络好像断了，检查一下再试" : "网络问题：\(m)"
        case .auth: return "这个版本的免费通道没鉴权通过，先升级 App 再试"
        case .quota: return "今天的免费额度用完了，明天再试"
        case .http(let code): return "模型服务返回 \(code)，稍后再试一次"
        case .empty: return "模型没有返回内容，再说一次试试"
        }
    }
}

final class AIClient {
    static let shared = AIClient()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 120
        return URLSession(configuration: cfg)
    }()

    private var header: [String: String] {
        [
            "x-wb-webapp-access-key": CloudCfg.publishableKey,
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
        ]
    }

    // MARK: 模型目录

    func models() async throws -> [AIModel] {
        guard let url = URL(string: CloudCfg.llmModels) else { throw AIError.network("") }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 20
        for (k, v) in header { req.setValue(v, forHTTPHeaderField: k) }
        let (data, resp) = try await session.data(for: req)
        try check(resp)
        do {
            return try JSONDecoder().decode([AIModel].self, from: data)
        } catch {
            throw AIError.network("模型列表解析失败")
        }
    }

    // MARK: 流式对话

    /// 发一轮对话，边收边回调，返回完整文本；网络抖动／网关 5xx 自动重试一次
    @discardableResult
    func stream(
        model: String,
        messages: [[String: String]],
        onDelta: ((String) -> Void)? = nil,
    ) async throws -> String {
        do {
            return try await streamOnce(model: model, messages: messages, onDelta: onDelta)
        } catch let e as AIError {
            guard Self.retryable(e) else { throw e }
            try? await Task.sleep(nanoseconds: 500_000_000)
            return try await streamOnce(model: model, messages: messages, onDelta: onDelta)
        }
    }

    private static func retryable(_ e: AIError) -> Bool {
        switch e {
        case .network: return true
        case .http(let code): return code >= 500
        default: return false
        }
    }

    private func streamOnce(
        model: String,
        messages: [[String: String]],
        onDelta: ((String) -> Void)? = nil,
    ) async throws -> String {
        guard let url = URL(string: CloudCfg.llmChat) else { throw AIError.network("") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        for (k, v) in header { req.setValue(v, forHTTPHeaderField: k) }
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": true,
            "temperature": 0.6,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, resp) = try await session.bytes(for: req)
        try check(resp)

        var full = ""
        do {
            for try await line in bytes.lines {
                guard line.hasPrefix("data:") else { continue }
                let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                if payload.isEmpty { continue }
                if payload == "[DONE]" { break }
                guard let data = payload.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }
                if obj["error"] is [String: Any] { throw AIError.http(500) }
                guard let choices = obj["choices"] as? [[String: Any]],
                      let delta = choices.first?["delta"] as? [String: Any],
                      let piece = delta["content"] as? String,
                      !piece.isEmpty
                else { continue }
                full += piece
                onDelta?(piece)
            }
        } catch let e as AIError {
            throw e
        } catch {
            // 中途断流：已经吐出来的字保留
            if full.isEmpty { throw AIError.network(error.localizedDescription) }
            return full
        }
        guard !full.isEmpty else { throw AIError.empty }
        return full
    }

    /// 一次性拿完整结果（内部仍然是流，收完再返回）
    func complete(model: String, system: String, user: String) async throws -> String {
        try await stream(
            model: model,
            messages: [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ]
        )
    }

    private func check(_ resp: URLResponse) throws {
        guard let http = resp as? HTTPURLResponse else { throw AIError.network("") }
        switch http.statusCode {
        case 200...299: return
        case 401, 403: throw AIError.auth
        case 429: throw AIError.quota("")
        default: throw AIError.http(http.statusCode)
        }
    }
}
