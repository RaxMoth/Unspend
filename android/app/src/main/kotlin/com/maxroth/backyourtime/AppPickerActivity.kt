package com.maxroth.backyourtime

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.Button
import android.widget.CheckBox
import android.widget.ImageView
import android.widget.ListView
import android.widget.TextView
import java.util.concurrent.Executors

/**
 * Lets the user choose the apps of a profile.
 *
 * Android has no system picker like iOS, so this is the app's own: every
 * app with a launcher icon, except the few that must never be blocked
 * ([InstalledApps.protectedPackages]). The choice is stored on the native
 * side; Dart only learns how many apps were chosen.
 */
class AppPickerActivity : Activity() {
    private val selected = HashSet<String>()
    private var apps: List<InstalledApp> = emptyList()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_app_picker)

        val profileId = intent.getStringExtra(EXTRA_PROFILE_ID)
        if (profileId == null) {
            finish()
            return
        }
        val store = sharedStore()
        selected += savedInstanceState?.getStringArrayList(STATE_SELECTED) ?: store.selection(profileId)

        intent.getStringExtra(EXTRA_TITLE)?.let { findViewById<TextView>(R.id.picker_title).text = it }
        findViewById<Button>(R.id.picker_cancel).apply {
            intent.getStringExtra(EXTRA_CANCEL)?.let { text = it }
            setOnClickListener { finish() }
        }
        findViewById<Button>(R.id.picker_save).apply {
            intent.getStringExtra(EXTRA_SAVE)?.let { text = it }
            setOnClickListener {
                // Apps that were uninstalled since drop out of the selection.
                val chosen = selected.intersect(apps.map { it.packageName }.toSet())
                store.setSelection(profileId, chosen)
                setResult(RESULT_OK, Intent().putExtra(EXTRA_COUNT, chosen.size))
                finish()
            }
            isEnabled = false
        }

        // Reading names and icons of every app takes a moment.
        val main = Handler(Looper.getMainLooper())
        Executors.newSingleThreadExecutor().execute {
            val loaded = InstalledApps.launchable(applicationContext)
            main.post { if (!isDestroyed) show(loaded) }
        }
    }

    private fun show(loaded: List<InstalledApp>) {
        apps = loaded
        findViewById<View>(R.id.picker_loading).visibility = View.GONE
        findViewById<Button>(R.id.picker_save).isEnabled = true
        findViewById<ListView>(R.id.picker_list).apply {
            adapter = Adapter()
            setOnItemClickListener { _, row, position, _ ->
                val packageName = apps[position].packageName
                if (!selected.remove(packageName)) selected += packageName
                row.findViewById<CheckBox>(R.id.app_check).isChecked = packageName in selected
            }
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putStringArrayList(STATE_SELECTED, ArrayList(selected))
    }

    private inner class Adapter : BaseAdapter() {
        override fun getCount(): Int = apps.size
        override fun getItem(position: Int): InstalledApp = apps[position]
        override fun getItemId(position: Int): Long = position.toLong()

        override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
            val row = convertView ?: layoutInflater.inflate(R.layout.item_app, parent, false)
            val app = apps[position]
            row.findViewById<ImageView>(R.id.app_icon).setImageDrawable(app.icon)
            row.findViewById<TextView>(R.id.app_label).text = app.label
            row.findViewById<CheckBox>(R.id.app_check).isChecked = app.packageName in selected
            return row
        }
    }

    companion object {
        const val EXTRA_COUNT = "count"
        private const val EXTRA_PROFILE_ID = "profileId"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_CANCEL = "cancel"
        private const val EXTRA_SAVE = "save"
        private const val STATE_SELECTED = "selected"

        fun intent(
            context: Context,
            profileId: String,
            title: String?,
            cancel: String?,
            save: String?,
        ): Intent = Intent(context, AppPickerActivity::class.java)
            .putExtra(EXTRA_PROFILE_ID, profileId)
            .putExtra(EXTRA_TITLE, title)
            .putExtra(EXTRA_CANCEL, cancel)
            .putExtra(EXTRA_SAVE, save)
    }
}
