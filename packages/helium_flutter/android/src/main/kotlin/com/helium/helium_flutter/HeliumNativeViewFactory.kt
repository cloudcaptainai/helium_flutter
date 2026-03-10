package com.helium.helium_flutter

import android.app.Activity
import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformViewFactory

class HeliumNativeViewFactory(
    private val channel: MethodChannel
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    var activity: Activity? = null

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String?, Any?>?
        // Prefer Activity context for WebView rendering; fall back to the provided context
        val viewContext = activity ?: context
        return HeliumNativeView(viewContext, viewId, creationParams, channel)
    }
}
