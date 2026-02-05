package com.helium.helium_flutter

import android.os.Handler
import android.os.Looper
import com.tryhelium.paywall.core.logger.HeliumLogger
import io.flutter.plugin.common.MethodChannel

/**
 * Bridging logger that forwards native SDK logs to Flutter while also
 * logging to stdout (logcat) for local debugging.
 *
 * Log level mapping to match iOS:
 * - e (error) -> level 1
 * - w (warn) -> level 2
 * - i (info) -> level 3
 * - d (debug) -> level 4
 * - v (verbose/trace) -> level 5
 */
class BridgingLogger(private val channel: MethodChannel) : HeliumLogger {
    override val logTag: String = "Helium"

    // Also log to stdout so logcat still works
    private val stdoutLogger = HeliumLogger.Stdout

    override fun e(message: String) {
        sendLogEvent(level = 1, message = message)
    }

    override fun w(message: String) {
        sendLogEvent(level = 2, message = message)
    }

    override fun i(message: String) {
        sendLogEvent(level = 3, message = message)
    }

    override fun d(message: String) {
        sendLogEvent(level = 4, message = message)
    }

    override fun v(message: String) {
        sendLogEvent(level = 5, message = message)
    }

    private fun sendLogEvent(level: Int, message: String) {
        val eventData = mapOf(
            "level" to level,
            "category" to logTag,
            "message" to "[$logTag] $message",
            "metadata" to emptyMap<String, String>()
        )
        Handler(Looper.getMainLooper()).post {
            channel.invokeMethod("onHeliumLogEvent", eventData)
        }
    }
}
