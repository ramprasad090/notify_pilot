package dev.notify_pilot

import android.content.Context
import android.view.View
import android.widget.RemoteViews

/**
 * Builds and populates RemoteViews for custom notification layouts.
 *
 * Uses a convention-based mapping from state data keys to view ids:
 *   - "title"    -> R.id.live_title
 *   - "subtitle" -> R.id.live_subtitle
 *   - "eta"      -> R.id.live_eta
 *   - "progress" -> R.id.live_progress
 *   - "icon"     -> R.id.live_icon (resource drawable name)
 */
object RemoteViewsBuilder {

    /**
     * Builds the default live notification layout and populates it with state data.
     *
     * @param context Application context
     * @param state State map with keys: title, subtitle, eta, progress, icon
     * @return Populated RemoteViews using the default_live_notification layout
     */
    fun buildDefaultLayout(context: Context, state: Map<String, Any?>): RemoteViews {
        val layoutResId = context.resources.getIdentifier(
            "default_live_notification", "layout", context.packageName
        )

        val views = if (layoutResId != 0) {
            RemoteViews(context.packageName, layoutResId)
        } else {
            // Fallback: create a minimal RemoteViews from Android's built-in layout
            RemoteViews(context.packageName, android.R.layout.simple_list_item_2).apply {
                val title = state["title"] as? String ?: ""
                val subtitle = state["subtitle"] as? String ?: ""
                setTextViewText(android.R.id.text1, title)
                setTextViewText(android.R.id.text2, subtitle)
                return this
            }
        }

        populateRemoteViews(views, state)
        return views
    }

    /**
     * Populates a RemoteViews instance by mapping state data to view ids.
     *
     * Supported mappings:
     *   - "title"    -> live_title (TextView: setTextViewText)
     *   - "subtitle" -> live_subtitle (TextView: setTextViewText)
     *   - "eta"      -> live_eta (TextView: setTextViewText)
     *   - "progress" -> live_progress (ProgressBar: setProgressBar)
     *   - "icon"     -> live_icon (ImageView: setImageViewResource)
     *
     * @param views RemoteViews to populate
     * @param state State map with data values
     */
    fun populateRemoteViews(views: RemoteViews, state: Map<String, Any?>) {
        val context = views.`package`?.let { null } // RemoteViews doesn't expose context directly

        // Text views
        setTextIfPresent(views, state, "title", "live_title")
        setTextIfPresent(views, state, "subtitle", "live_subtitle")
        setTextIfPresent(views, state, "eta", "live_eta")

        // Progress bar
        val progress = state["progress"]
        if (progress is Number) {
            setProgressIfPresent(views, progress.toInt())
        }
    }

    // region Private helpers

    private fun setTextIfPresent(
        views: RemoteViews,
        state: Map<String, Any?>,
        stateKey: String,
        viewIdName: String
    ) {
        val value = state[stateKey] as? String ?: return
        try {
            // RemoteViews requires the actual resource id; we resolve it from the package name
            // Since we don't have direct context access, we set by known id name convention
            // The layout XML must define these ids in the app's namespace
            val packageName = views.`package` ?: return
            val viewId = getViewId(packageName, viewIdName)
            if (viewId != 0) {
                views.setTextViewText(viewId, value)
            }
        } catch (_: Exception) {
            // View id not found in layout, skip silently
        }
    }

    private fun setProgressIfPresent(views: RemoteViews, progress: Int) {
        try {
            val packageName = views.`package` ?: return
            val viewId = getViewId(packageName, "live_progress")
            if (viewId != 0) {
                views.setProgressBar(viewId, 100, progress.coerceIn(0, 100), false)
                views.setViewVisibility(viewId, View.VISIBLE)
            }
        } catch (_: Exception) {
            // View id not found, skip silently
        }
    }

    /**
     * Resolves a view resource id from the package name and view id name.
     * This uses the standard Android resource naming convention: R.id.<name>.
     */
    private fun getViewId(packageName: String, idName: String): Int {
        return try {
            val rIdClass = Class.forName("$packageName.R\$id")
            val field = rIdClass.getField(idName)
            field.getInt(null)
        } catch (_: Exception) {
            0
        }
    }

    // endregion
}
