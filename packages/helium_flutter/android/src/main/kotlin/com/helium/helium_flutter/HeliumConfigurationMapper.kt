package com.helium.helium_flutter

import com.tryhelium.paywall.core.HeliumEnvironment
import com.tryhelium.paywall.core.HeliumUserTraits
import com.tryhelium.paywall.core.HeliumUserTraitsArgument

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
        is Double -> HeliumUserTraitsArgument.DoubleParam(value)
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
