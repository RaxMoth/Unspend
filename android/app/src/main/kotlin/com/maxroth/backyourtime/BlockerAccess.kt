package com.maxroth.backyourtime

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.provider.Settings
import com.maxroth.backyourtime.core.KeyValueStore
import com.maxroth.backyourtime.core.SharedStore

/**
 * The permission everything rests on: the user switching on Unspend's
 * accessibility service, which is how the app learns which app is in front.
 */
object BlockerAccess {
    /** Whether the user has switched the blocker service on. */
    fun isEnabled(context: Context): Boolean {
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val mine = ComponentName(context, BlockerService::class.java)
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == mine }
    }

    /** The system screen where the service is switched on and off. */
    fun settingsIntent(): Intent =
        Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
}

/** [KeyValueStore] on the app's private preferences. */
class PrefsKeyValueStore(context: Context) : KeyValueStore {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    override fun getString(key: String): String? = prefs.getString(key, null)

    override fun putString(key: String, value: String?) {
        prefs.edit().apply { if (value == null) remove(key) else putString(key, value) }.apply()
    }

    override fun keys(): Set<String> = prefs.all.keys.toSet()

    companion object {
        private const val FILE = "unspend_blocker"
    }
}

/** The native side's store. */
fun Context.sharedStore(): SharedStore = SharedStore(PrefsKeyValueStore(this))
