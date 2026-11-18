package com.maxroth.backyourtime

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView

/**
 * The screen shown instead of a blocked app. Its only way out is the home
 * screen.
 *
 * The wording comes from the app, in its current language, through the
 * store.
 */
class BlockActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_block)

        val strings = sharedStore().shieldStrings
        val appName = intent.getStringExtra(EXTRA_PACKAGE)?.let { InstalledApps.label(this, it) }
        findViewById<TextView>(R.id.block_title).text = strings.title(appName)
        findViewById<TextView>(R.id.block_subtitle).text =
            strings.subtitle(intent.getStringExtra(EXTRA_PROFILE_NAME))
        findViewById<Button>(R.id.block_button).apply {
            text = strings.button
            setOnClickListener { goHome() }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() = goHome()

    private fun goHome() {
        startActivity(
            Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        finish()
    }

    companion object {
        private const val EXTRA_PACKAGE = "package"
        private const val EXTRA_PROFILE_NAME = "profileName"

        fun intent(context: Context, packageName: String, profileName: String): Intent =
            Intent(context, BlockActivity::class.java)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TASK or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION,
                )
                .putExtra(EXTRA_PACKAGE, packageName)
                .putExtra(EXTRA_PROFILE_NAME, profileName)
    }
}
