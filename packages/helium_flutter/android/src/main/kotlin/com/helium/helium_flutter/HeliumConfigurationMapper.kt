package com.helium.helium_flutter

import android.content.Context
import com.tryhelium.paywall.core.HeliumEnvironment
import com.tryhelium.paywall.core.HeliumUserTraits
import com.tryhelium.paywall.core.HeliumUserTraitsArgument
import com.tryhelium.paywall.core.HeliumFallbackConfig
import java.io.File
import java.io.FileOutputStream

private const val DEFAULT_USE_LOADING_STATE = true
private const val DEFAULT_LOADING_BUDGET_MS = 2000L // consider grabbing this from Android sdk as future enhancment

internal fun String?.toEnvironment(): HeliumEnvironment {
    if (this == null) return HeliumEnvironment.PRODUCTION

    return when (this) {
        "sandbox" -> HeliumEnvironment.SANDBOX
        "production" -> HeliumEnvironment.PRODUCTION
        else -> HeliumEnvironment.SANDBOX
    }
}

// Helper functions for type conversion

/**
 * Recursively converts special marker strings back to boolean values to restore
 * type information that was preserved when passing through platform channels.
 *
 * Flutter's platform channels convert booleans to integers (0/1), so we use
 * special marker strings to preserve the original intent. This helper converts:
 * - "__helium_flutter_bool_true__" -> true
 * - "__helium_flutter_bool_false__" -> false
 * - All other values remain unchanged
 */
private fun convertMarkersToBooleans(input: Map<String, Any?>?): Map<String, Any?>? {
    if (input == null) return null
    return input.mapValues { (_, value) ->
        convertValueMarkersToBooleans(value)
    }
}

private fun convertValueMarkersToBooleans(value: Any?): Any? {
    return when (value) {
        "__helium_flutter_bool_true__" -> true
        "__helium_flutter_bool_false__" -> false
        is String -> value
        is Map<*, *> -> {
            @Suppress("UNCHECKED_CAST")
            convertMarkersToBooleans(value as? Map<String, Any?>)
        }

        is List<*> -> value.map { convertValueMarkersToBooleans(it) }
        else -> value
    }
}

internal fun convertToHeliumUserTraits(input: Map<String, Any?>?): HeliumUserTraits? {
    if (input == null) return null
    val convertedInput = convertMarkersToBooleans(input) ?: return null
    val traits = convertedInput.mapValues { (_, value) ->
        convertToHeliumUserTraitsArgument(value)
    }.filterValues { it != null }.mapValues { it.value!! }
    return HeliumUserTraits(traits)
}

internal fun convertToHeliumUserTraitsArgument(value: Any?): HeliumUserTraitsArgument? {
    return when (value) {
        is String -> HeliumUserTraitsArgument.StringParam(value)
        is Int -> HeliumUserTraitsArgument.IntParam(value)
        is Long -> HeliumUserTraitsArgument.LongParam(value)
        is Double -> HeliumUserTraitsArgument.DoubleParam(value.toString())
        is Boolean -> HeliumUserTraitsArgument.BooleanParam(value)
        is List<*> -> {
            val items = value.mapNotNull { convertToHeliumUserTraitsArgument(it) }
            HeliumUserTraitsArgument.Array(items)
        }

        is Map<*, *> -> {
            @Suppress("UNCHECKED_CAST")
            val properties = (value as? Map<String, Any?>)?.mapValues { (_, v) ->
                convertToHeliumUserTraitsArgument(v)
            }?.filterValues { it != null }?.mapValues { it.value!! } ?: emptyMap()
            HeliumUserTraitsArgument.Complex(properties)
        }

        else -> null
    }
}

internal fun convertToHeliumFallbackConfig(
    paywallLoadingConfig: Map<String, Any?>?,
    fallbackAssetPath: String?,
    flutterAssetPath: String?,
    context: Context?
): HeliumFallbackConfig? {
    if (paywallLoadingConfig == null && fallbackAssetPath == null) return null

    // Pre-emptively store the fallback bundle to avoid path traversal issues
    val finalFallbackBundleName = if (flutterAssetPath != null && context != null) {
        try {
            // Extract just the filename (remove flutter_assets/ prefix)
            val filename = fallbackAssetPath?.substringAfterLast('/') ?: flutterAssetPath.substringAfterLast('/')

            // Get SDK's local directory
            val heliumLocalDir = context.getDir("helium_local", Context.MODE_PRIVATE)
            val destinationFile = File(heliumLocalDir, filename)

            // Copy asset to local storage if not already there
            if (!destinationFile.exists()) {
                context.assets.open(flutterAssetPath).use { inputStream ->
                    FileOutputStream(destinationFile).use { outputStream ->
                        inputStream.copyTo(outputStream)
                    }
                }
            }

            // Return just the filename for SDK
            filename
        } catch (e: Exception) {
            null
        }
    } else {
        null
    }

    if (paywallLoadingConfig == null) {
        return HeliumFallbackConfig(
            useLoadingState = DEFAULT_USE_LOADING_STATE,
            fallbackBundleName = finalFallbackBundleName
        )
    }

    val convertedConfig = convertMarkersToBooleans(paywallLoadingConfig) ?: return null

    val useLoadingState = convertedConfig["useLoadingState"] as? Boolean ?: DEFAULT_USE_LOADING_STATE
    val loadingBudget = (convertedConfig["loadingBudget"] as? Number)?.toLong() ?: DEFAULT_LOADING_BUDGET_MS

    var perTriggerLoadingConfig: Map<String, HeliumFallbackConfig>? = null
    val perTriggerDict = convertedConfig["perTriggerLoadingConfig"] as? Map<*, *>
    if (perTriggerDict != null) {
        perTriggerLoadingConfig = perTriggerDict.mapNotNull { (key, value) ->
            if (key is String && value is Map<*, *>) {
                @Suppress("UNCHECKED_CAST")
                val config = value as? Map<String, Any?>
                val triggerUseLoadingState = config?.get("useLoadingState") as? Boolean
                val triggerLoadingBudget = (config?.get("loadingBudget") as? Number)?.toLong()
                key to HeliumFallbackConfig(
                    useLoadingState = triggerUseLoadingState ?: DEFAULT_USE_LOADING_STATE,
                    loadingBudgetInMs = triggerLoadingBudget ?: DEFAULT_LOADING_BUDGET_MS
                )
            } else {
                null
            }
        }.toMap()
    }

    return HeliumFallbackConfig(
        useLoadingState = useLoadingState,
        loadingBudgetInMs = loadingBudget,
        perTriggerLoadingConfig = perTriggerLoadingConfig,
        fallbackBundleName = finalFallbackBundleName
    )
}