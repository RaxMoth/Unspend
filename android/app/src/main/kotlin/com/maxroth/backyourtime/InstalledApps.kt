package com.maxroth.backyourtime

import android.content.Context
import android.content.Intent
import android.graphics.drawable.Drawable
import android.provider.Settings
import android.telecom.TelecomManager
import java.text.Collator

/** An app the user can put into a profile. */
class InstalledApp(val packageName: String, val label: String, val icon: Drawable)

object InstalledApps {
    /**
     * Apps that are never offered and never blocked: Unspend itself, the
     * home screen (blocking it would lock the user out of the phone), the
     * phone app (emergency calls) and the system settings (where Unspend's
     * access is switched off).
     */
    fun protectedPackages(context: Context): Set<String> {
        val pm = context.packageManager
        val protected = mutableSetOf(context.packageName, "com.android.systemui")

        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        pm.queryIntentActivities(home, 0).mapTo(protected) { it.activityInfo.packageName }

        val settings = Intent(Settings.ACTION_SETTINGS)
        pm.queryIntentActivities(settings, 0).mapTo(protected) { it.activityInfo.packageName }

        val telecom = context.getSystemService(TelecomManager::class.java)
        telecom?.defaultDialerPackage?.let(protected::add)
        pm.queryIntentActivities(Intent(Intent.ACTION_DIAL), 0)
            .mapTo(protected) { it.activityInfo.packageName }

        return protected
    }

    /** Every app with a launcher icon that may be blocked, sorted by name. */
    fun launchable(context: Context): List<InstalledApp> {
        val pm = context.packageManager
        val protected = protectedPackages(context)
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val collator = Collator.getInstance()
        return pm.queryIntentActivities(launcher, 0)
            .asSequence()
            .map { it.activityInfo }
            .filter { it.packageName !in protected }
            .distinctBy { it.packageName }
            .map { InstalledApp(it.packageName, it.loadLabel(pm).toString(), it.loadIcon(pm)) }
            .sortedWith { a, b -> collator.compare(a.label, b.label) }
            .toList()
    }

    /** The name of [packageName] as the launcher shows it, if it is installed. */
    fun label(context: Context, packageName: String): String? = try {
        val pm = context.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
    } catch (_: Exception) {
        null
    }
}
