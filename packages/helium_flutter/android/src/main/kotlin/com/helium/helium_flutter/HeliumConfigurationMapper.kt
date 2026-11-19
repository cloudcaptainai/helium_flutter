package com.helium.helium_flutter

import com.tryhelium.paywall.core.HeliumEnvironment
import com.tryhelium.paywall.core.HeliumUserTraits
import com.tryhelium.paywall.core.HeliumUserTraitsArgument
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import com.tryhelium.paywall.core.HeliumUserTraits.Companion.create

internal fun String?.toEnvironment(): HeliumEnvironment {
    if (this == null) return HeliumEnvironment.PRODUCTION

    return when (this) {
        "sandbox" -> HeliumEnvironment.SANDBOX
        "production" -> HeliumEnvironment.PRODUCTION
        else -> HeliumEnvironment.PRODUCTION
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
private fun convertMarkersToBooleans(input: Map<String, Any>?): Map<String, Any>? {
    if (input == null) return null
    return input.mapValues { (_, value) ->
        convertValueMarkersToBooleans(value)
    }
}

private fun convertValueMarkersToBooleans(value: Any): Any {
    return when (value) {
        "__helium_flutter_bool_true__" -> true
        "__helium_flutter_bool_false__" -> false
        is String -> value
        is Map<*, *> -> {
            @Suppress("UNCHECKED_CAST")
            convertMarkersToBooleans(value as? Map<String, Any>) ?: emptyMap<String, Any>()
        }

        is List<*> -> value.filterNotNull().map { convertValueMarkersToBooleans(it) }
        else -> value
    }
}

internal fun convertToHeliumUserTraits(input: Map<String, Any>?): HeliumUserTraits? {
    if (input == null) return null
    val convertedInput = convertMarkersToBooleans(input) ?: return null
    return convertedInput.create()
}

internal fun convertHeliumUserTraitsToMap(traits: HeliumUserTraits): Map<String, Any> {
    return traits.traits.mapValues { (_, value) -> convertTraitArgumentToValue(value) }
}

private fun convertTraitArgumentToValue(argument: HeliumUserTraitsArgument): Any {
    return when (argument) {
        is HeliumUserTraitsArgument.StringParam -> argument.value
        is HeliumUserTraitsArgument.IntParam -> argument.value
        is HeliumUserTraitsArgument.LongParam -> argument.value
        is HeliumUserTraitsArgument.DoubleParam -> argument.value
        is HeliumUserTraitsArgument.BooleanParam -> argument.value
        is HeliumUserTraitsArgument.DateParam -> formatIso8601(argument.value)
        is HeliumUserTraitsArgument.Array -> argument.items.map { convertTraitArgumentToValue(it) }
        is HeliumUserTraitsArgument.Complex -> argument.properties.mapValues { (_, value) -> convertTraitArgumentToValue(value) }
    }
}

private fun formatIso8601(date: Date): String {
    val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
    formatter.timeZone = TimeZone.getTimeZone("UTC")
    return formatter.format(date)
}
