package com.zsonit.mengbao.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.net.HttpURLConnection
import java.net.URL

// 免密钥大模型客户端：主通道走 WorkBuddy 云服务的 /.cloud/llm，
// 家长不需要填任何 API Key，也不额外花钱。
// 主通道每天有免费额度，用完（429）会自动切到免密钥、无每日额度的备用链：
//   ① Kilo 免费网关 kilo-auto/free（自动挑最优免费模型）
//   ② Kilo 免费网关 openrouter/free
//   ③ Pollinations 开放接口
// 家长无感，不用配置任何东西。

data class AIModel(
    val id: String,
    val name: String? = null,
    val enabled: Boolean? = null,
) {
    val label: String get() = if (!name.isNullOrBlank()) name!! else id
    val usable: Boolean get() = enabled ?: true

    companion object {
        /** 界面只展示几种常用档位，避免一次列 30 多个 */
        fun quick(list: List<AIModel>): List<AIModel> {
            val picked = listOf("glm-5.3-flash", "auto", "deepseek-v4-flash", "glm-5.3", "hunyuan-chat")
            val out = list.filter { it.id in picked && it.usable }
                .sortedBy { picked.indexOf(it.id) }
            return out.ifEmpty { list.filter { it.usable }.take(3) }
        }
    }
}

class AIException(message: String, val retry: Boolean = false, val quota: Boolean = false) : Exception(message)

object AIClient {

    /** 备用免费链：免密钥、OpenAI 兼容、SSE 流式（与 iOS 保持一致） */
    private data class Fallback(val url: String, val model: String)

    private val fallbacks = listOf(
        Fallback("https://api.kilo.ai/api/gateway/chat/completions", "kilo-auto/free"),
        Fallback("https://api.kilo.ai/api/gateway/chat/completions", "openrouter/free"),
        Fallback("https://text.pollinations.ai/openai", "openai"),
    )

    private fun conn(url: String, method: String): HttpURLConnection =
        (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 20_000
            readTimeout = 90_000
            setRequestProperty("x-wb-webapp-access-key", CloudCfg.PUBLISHABLE_KEY)
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Accept", "text/event-stream")
        }

    private fun plainConn(url: String, method: String): HttpURLConnection =
        (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 20_000
            readTimeout = 90_000
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Accept", "text/event-stream")
        }

    suspend fun models(): List<AIModel> = withContext(Dispatchers.IO) {
        val c = conn(CloudCfg.LLM_MODELS, "GET")
        try {
            val code = c.responseCode
            if (code !in 200..299) throw err(code)
            val text = c.inputStream.bufferedReader().use(BufferedReader::readText)
            val arr = JSONArray(text)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                AIModel(
                    id = o.optString("id"),
                    name = o.optString("name").ifBlank { null },
                    enabled = if (o.has("enabled")) o.optBoolean("enabled", true) else null,
                )
            }
        } catch (e: AIException) {
            throw e
        } catch (e: Exception) {
            throw AIException("获取模型列表失败，检查一下网络", retry = true)
        } finally {
            c.disconnect()
        }
    }

    /**
     * 发一轮对话，收完流返回完整文本。
     * 网络抖动／网关 5xx 自动重试一次；免费额度用完（429）自动切备用免费链，不弹「额度用完」。
     */
    suspend fun complete(model: String, system: String, user: String): String {
        try {
            return completeOnce(model, system, user)
        } catch (e: AIException) {
            if (e.retry) {
                delay(500)
                try {
                    return completeOnce(model, system, user)
                } catch (e2: AIException) {
                    if (!e2.quota) throw e2
                    return viaFallbacks(system, user, e2)
                }
            }
            if (!e.quota) throw e
            return viaFallbacks(system, user, e)
        }
    }

    /** 额度用完后的备用链：Kilo 双车道 → Pollinations 兜底 */
    private suspend fun viaFallbacks(system: String, user: String, cause: AIException): String {
        for (f in fallbacks) {
            runCatching {
                return withContext(Dispatchers.IO) { postSSE(f.url, f.model, system, user) }
            }.onFailure {
                AppLog.w("AI", "备用通道 ${f.model} 失败：${it.message}")
            }
        }
        throw cause
    }

    private fun requestBody(model: String, system: String, user: String): String = JSONObject().apply {
        put("model", model)
        put("stream", true)
        put("temperature", 0.6)
        put(
            "messages", JSONArray().apply {
                put(JSONObject().put("role", "system").put("content", system))
                put(JSONObject().put("role", "user").put("content", user))
            },
        )
    }.toString()

    private suspend fun completeOnce(model: String, system: String, user: String): String =
        withContext(Dispatchers.IO) { postSSE(CloudCfg.LLM_CHAT, model, system, user, withAuth = true) }

    private fun postSSE(url: String, model: String, system: String, user: String, withAuth: Boolean = false): String {
        val body = requestBody(model, system, user)
        val c = if (withAuth) conn(url, "POST") else plainConn(url, "POST")
        return try {
            c.doOutput = true
            c.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val code = c.responseCode
            if (code !in 200..299) throw err(code)

            val sb = StringBuilder()
            c.inputStream.bufferedReader().use { reader ->
                var line = reader.readLine()
                while (line != null) {
                    if (line.startsWith("data:")) {
                        val payload = line.removePrefix("data:").trim()
                        if (payload == "[DONE]") break
                        if (payload.isNotEmpty()) {
                            val obj = runCatching { JSONObject(payload) }.getOrNull()
                            if (obj != null) {
                                if (obj.has("error")) break
                                val choices = obj.optJSONArray("choices")
                                val delta = choices?.optJSONObject(0)?.optJSONObject("delta")
                                val piece = delta?.optString("content") ?: ""
                                if (piece.isNotEmpty()) sb.append(piece)
                            }
                        }
                    }
                    line = reader.readLine()
                }
            }
            sb.toString().ifEmpty { throw AIException("模型没有返回内容，再说一次试试", retry = true) }
        } catch (e: AIException) {
            throw e
        } catch (e: Exception) {
            throw AIException("网络好像断了，检查一下再试", retry = true)
        } finally {
            c.disconnect()
        }
    }

    private fun err(code: Int): AIException = when (code) {
        in 401..403 -> AIException("这个版本的免费通道没鉴权通过，先升级 App 再试")
        429 -> AIException("今天的免费额度用完了，明天再试", quota = true)
        else -> AIException("模型服务返回 $code，稍后再试一次", retry = code >= 500)
    }
}
