package com.helium.helium_flutter

import android.content.Context
import android.view.View
import android.widget.TextView
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
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
            paywallView.layoutParams = android.view.ViewGroup.LayoutParams(
                android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                android.view.ViewGroup.LayoutParams.MATCH_PARENT
            )

            (context as? LifecycleOwner)?.let { owner ->
                paywallView.setViewTreeLifecycleOwner(owner)
            }

            // Defer loadPaywall until the view is part of the window hierarchy.
            paywallView.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
                override fun onViewAttachedToWindow(v: View) {
                    // Remove listener so loadPaywall is only called once
                    v.removeOnAttachStateChangeListener(this)
                    paywallView.loadPaywall(trigger = trigger, navigationDispatcher = { command ->
                        // Do nothing. Callers need to listen to the paywall events
                    })
                }

                override fun onViewDetachedFromWindow(v: View) { }
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
