package com.helium.helium_flutter

import android.content.Context
import android.view.View
import android.widget.TextView
import io.flutter.plugin.platform.PlatformView
import com.tryhelium.paywall.core.Helium
import com.tryhelium.paywall.core.event.HeliumEventListener
import com.tryhelium.paywall.core.event.HeliumEventDictionaryMapper
import com.tryhelium.paywall.ui.HeliumPaywallView
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper

class HeliumNativeView(
    context: Context,
    id: Int,
    creationParams: Map<String?, Any?>?,
    private val channel: MethodChannel
) : PlatformView {
    private val view: View

    init {
        val trigger = creationParams?.get("trigger") as? String ?: ""
        view = upsellViewForTrigger(context, trigger)
    }

    override fun getView(): View {
        return view
    }

    override fun dispose() {}

    private fun upsellViewForTrigger(context: Context, trigger: String): View {
        val eventListener = HeliumEventListener { event ->
            val eventData = HeliumEventDictionaryMapper.toDictionary(event)
            Handler(Looper.getMainLooper()).post {
                channel.invokeMethod("onPaywallEventHandler", eventData)
            }
        }
        
        return try {
            val paywallView = HeliumPaywallView(context = context)
            paywallView.loadPaywall(trigger = trigger, navigationDispatcher = { command ->
                // TODO -> Not sure what to do with this navigation command.
            })
            paywallView.setPaywallEventHandlers(eventListener)

            paywallView
        } catch (e: Exception) {
            TextView(context).apply {
                text = "Error creating Helium View: ${e.message}"
            }
        }
    }
}
