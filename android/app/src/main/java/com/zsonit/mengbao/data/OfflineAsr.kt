package com.zsonit.mengbao.data

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import com.k2fsa.sherpa.onnx.FeatureConfig
import com.k2fsa.sherpa.onnx.OnlineModelConfig
import com.k2fsa.sherpa.onnx.OnlineRecognizer
import com.k2fsa.sherpa.onnx.OnlineRecognizerConfig
import com.k2fsa.sherpa.onnx.OnlineTransducerModelConfig
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 离线中文语音识别（sherpa-onnx + streaming zipformer zh-14M int8）。
 *
 * 为什么不直接用系统 SpeechRecognizer：那是谷歌服务，国产手机大多没有，
 * 之前「一直用不了、提示没有语音模块」就是因为它。这套引擎完全离线、
 * 免费、不要任何 Key，模型（约 25MB）内置在 assets/asr 里，首次使用时
 * 复制到应用私有目录，之后走本地推理，没有网也能识别。
 */
object OfflineAsr {

    private const val SR = 16000
    private val MODEL_FILES = listOf(
        "tokens.txt",
        "encoder-epoch-99-avg-1.int8.onnx",
        "decoder-epoch-99-avg-1.int8.onnx",
        "joiner-epoch-99-avg-1.int8.onnx",
    )

    @Volatile private var recognizer: OnlineRecognizer? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val recording = AtomicBoolean(false)

    /** 引擎就绪返回 null，否则返回给用户看的错误 */
    fun ensure(context: Context): String? {
        if (recognizer != null) return null
        synchronized(this) {
            if (recognizer != null) return null
            return try {
                val dir = File(context.filesDir, "asr").apply { mkdirs() }
                for (n in MODEL_FILES) {
                    val f = File(dir, n)
                    if (!f.exists() || f.length() == 0L) {
                        context.assets.open("asr/$n").use { input ->
                            f.outputStream().use { output -> input.copyTo(output) }
                        }
                    }
                }
                val config = OnlineRecognizerConfig(
                    featConfig = FeatureConfig(sampleRate = SR, featureDim = 80),
                    modelConfig = OnlineModelConfig(
                        transducer = OnlineTransducerModelConfig(
                            encoder = File(dir, "encoder-epoch-99-avg-1.int8.onnx").absolutePath,
                            decoder = File(dir, "decoder-epoch-99-avg-1.int8.onnx").absolutePath,
                            joiner = File(dir, "joiner-epoch-99-avg-1.int8.onnx").absolutePath,
                        ),
                        tokens = File(dir, "tokens.txt").absolutePath,
                        numThreads = 2,
                    ),
                    decodingMethod = "greedy_search",
                    enableEndpoint = true,
                )
                recognizer = OnlineRecognizer(assetManager = null, config = config)
                null
            } catch (e: Throwable) {
                "语音引擎初始化失败：${e.message ?: e.javaClass.simpleName}"
            }
        }
    }

    interface Callbacks {
        /** 边说边出的实时转写 */
        fun onPartial(text: String)
        /** 松手 / 结束后的完整文本（可能为空） */
        fun onFinal(text: String)
        fun onError(msg: String)
    }

    val isRunning: Boolean get() = recording.get()

    /** 开始录音识别。调用方需已取得 RECORD_AUDIO 权限。 */
    @SuppressLint("MissingPermission")
    fun start(cb: Callbacks) {
        if (!recording.compareAndSet(false, true)) return
        val rec = recognizer
        if (rec == null) {
            recording.set(false)
            cb.onError("语音引擎还没准备好，再按一次")
            return
        }
        executor.execute {
            var ar: AudioRecord? = null
            try {
                val minBuf = AudioRecord.getMinBufferSize(SR, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
                ar = AudioRecord(
                    MediaRecorder.AudioSource.MIC, SR,
                    AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
                    maxOf(minBuf, 3200) * 2,
                )
                ar.startRecording()

                val stream = rec.createStream()
                val buf = ShortArray(1600) // 100 ms
                val parts = StringBuilder()
                try {
                    while (recording.get()) {
                        val n = ar.read(buf, 0, buf.size)
                        if (n <= 0) continue
                        val samples = FloatArray(n) { buf[it] / 32768f }
                        stream.acceptWaveform(samples, SR)
                        while (rec.isReady(stream)) rec.decode(stream)
                        val text = rec.getResult(stream).text
                        val shown = (parts.toString() + text).trim()
                        if (shown.isNotEmpty()) cb.onPartial(shown)
                        // 说完一小句（停顿超过阈值）先收一段，接着往下听
                        if (rec.isEndpoint(stream)) {
                            if (text.isNotBlank()) {
                                if (parts.isNotEmpty()) parts.append(' ')
                                parts.append(text.trim())
                                cb.onPartial(parts.toString())
                            }
                            rec.reset(stream)
                        }
                    }
                } finally {
                    stream.inputFinished()
                    while (rec.isReady(stream)) rec.decode(stream)
                    val tail = rec.getResult(stream).text
                    val out = (parts.toString() + " " + tail).trim()
                    try { ar.stop() } catch (_: Exception) {}
                    try { ar.release() } catch (_: Exception) {}
                    recording.set(false)
                    if (out.isEmpty()) cb.onFinal("") else cb.onFinal(out)
                }
            } catch (e: Throwable) {
                recording.set(false)
                try { ar?.release() } catch (_: Exception) {}
                cb.onError("录音出错：${e.message ?: e.javaClass.simpleName}")
            }
        }
    }

    /** 结束并取结果（触发 onFinal） */
    fun stop() {
        recording.set(false)
    }
}
