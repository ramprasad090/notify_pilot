package dev.notify_pilot

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class PermissionHelper {

    companion object {
        const val REQUEST_CODE_POST_NOTIFICATIONS = 10401

        /**
         * Returns current permission status as a string:
         * "granted", "denied", or "notDetermined".
         */
        fun getPermissionStatus(activity: Activity?): String {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                // Before API 33, POST_NOTIFICATIONS permission does not exist; always granted.
                return "granted"
            }

            if (activity == null) return "notDetermined"

            return when {
                ContextCompat.checkSelfPermission(
                    activity, Manifest.permission.POST_NOTIFICATIONS
                ) == PackageManager.PERMISSION_GRANTED -> "granted"

                ActivityCompat.shouldShowRequestPermissionRationale(
                    activity, Manifest.permission.POST_NOTIFICATIONS
                ) -> "denied"

                else -> "notDetermined"
            }
        }

        /**
         * Requests POST_NOTIFICATIONS permission on API 33+.
         * Returns true if the request was initiated, false if not needed.
         */
        fun requestPermission(activity: Activity?): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                return false
            }

            if (activity == null) return false

            if (ContextCompat.checkSelfPermission(
                    activity, Manifest.permission.POST_NOTIFICATIONS
                ) == PackageManager.PERMISSION_GRANTED
            ) {
                return false
            }

            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_CODE_POST_NOTIFICATIONS
            )
            return true
        }
    }
}
