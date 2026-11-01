package com.zsonit.mengbao.data

// 云服务配置（配对同步 + 免密钥大模型共用）。
// publishableKey 只代表「哪个应用」，本身不带权限；大模型走 /.cloud/llm，家长无需任何 API Key。
object CloudCfg {
    const val ENDPOINT = "https://mengbao-sync.app.workbuddy.host"
    const val PUBLISHABLE_KEY = "wbpk_z3Qd2DmHRK20lYTyzpjsTH_DG9v1WdRyKgkBsMLewH3mh5Br7EOcUlR"

    const val LLM_CHAT = "$ENDPOINT/.cloud/llm/chat/completions"
    const val LLM_MODELS = "$ENDPOINT/.cloud/llm/models"
    const val DB_REST = "$ENDPOINT/.cloud/database/rest/v1/mengbao_sync"
}
