import Foundation

// MARK: - 云服务配置（同步 + 免密钥大模型共用）
//
// 这里的 publishableKey 只代表「哪个应用」，本身不带权限，服务端还会做来源校验；
// 大模型走 /.cloud/llm/chat/completions，家长不需要申请任何 API Key，也不产生费用。
enum CloudCfg {
    static let endpoint = "https://mengbao-sync.app.workbuddy.host"
    static let publishableKey = "wbpk_z3Qd2DmHRK20lYTyzpjsTH_DG9v1WdRyKgkBsMLewH3mh5Br7EOcUlR"

    /// 免密钥大模型：流式对话
    static let llmChat = endpoint + "/.cloud/llm/chat/completions"
    /// 免密钥大模型：可用模型目录
    static let llmModels = endpoint + "/.cloud/llm/models"
}
