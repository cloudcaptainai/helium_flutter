package com.helium.helium_flutter

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformViewFactory

class HeliumNativeViewFactory(private val channel: MethodChannel) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<String?, Any?>?
        return HeliumNativeView(context, viewId, creationParams, channel)
    }
}
