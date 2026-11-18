package com.maxroth.backyourtime.core

import org.json.JSONException
import org.json.JSONObject

/**
 * Text of the block screen. The app pushes the strings for its current
 * in-app language; the block screen only fills in the blanks. Mirrors
 * `ShieldStrings` in `SharedStore.swift`.
 */
data class ShieldStrings(
    /** `{app}` is replaced with the blocked app. */
    val titleTemplate: String,
    /** `{profile}` is replaced with the name of the blocking profile. */
    val subtitleTemplate: String,
    /** Used when the blocking profile has no name. */
    val subtitleGeneric: String,
    val button: String,
    val appFallback: String,
    val websiteFallback: String,
) {
    fun title(appName: String?): String =
        titleTemplate.replace("{app}", if (appName.isNullOrEmpty()) appFallback else appName)

    fun subtitle(profileName: String?): String =
        if (profileName.isNullOrEmpty()) subtitleGeneric
        else subtitleTemplate.replace("{profile}", profileName)

    fun toJson(): String = JSONObject().apply {
        put(TITLE, titleTemplate)
        put(SUBTITLE, subtitleTemplate)
        put(SUBTITLE_GENERIC, subtitleGeneric)
        put(BUTTON, button)
        put(APP_FALLBACK, appFallback)
        put(WEBSITE_FALLBACK, websiteFallback)
    }.toString()

    companion object {
        // The same keys the Dart side sends (`ScreenTimeArg`).
        const val TITLE = "titleTemplate"
        const val SUBTITLE = "subtitleTemplate"
        const val SUBTITLE_GENERIC = "subtitleGeneric"
        const val BUTTON = "button"
        const val APP_FALLBACK = "appFallback"
        const val WEBSITE_FALLBACK = "websiteFallback"

        val english = ShieldStrings(
            titleTemplate = "{app} is blocked",
            subtitleTemplate = "Blocked by “{profile}” in Unspend",
            subtitleGeneric = "Blocked by Unspend",
            button = "Go Back",
            appFallback = "This app",
            websiteFallback = "This website",
        )

        /** Null unless every string is present and not empty. */
        fun fromMap(map: Map<*, *>): ShieldStrings? {
            fun text(key: String) = (map[key] as? String)?.takeIf { it.isNotEmpty() }
            return ShieldStrings(
                titleTemplate = text(TITLE) ?: return null,
                subtitleTemplate = text(SUBTITLE) ?: return null,
                subtitleGeneric = text(SUBTITLE_GENERIC) ?: return null,
                button = text(BUTTON) ?: return null,
                appFallback = text(APP_FALLBACK) ?: return null,
                websiteFallback = text(WEBSITE_FALLBACK) ?: return null,
            )
        }

        fun fromJson(json: String): ShieldStrings? = try {
            val o = JSONObject(json)
            fromMap(o.keys().asSequence().associateWith { o.get(it) })
        } catch (_: JSONException) {
            null
        }
    }
}
