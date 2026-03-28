package dev.notify_pilot

import android.util.Log

/**
 * Optional FCM integration via reflection. No compile-time Firebase dependency required.
 * If FirebaseMessaging is on the classpath (host app includes firebase_messaging),
 * this handler will delegate to it. Otherwise, methods return gracefully.
 */
class FcmHandler {

    companion object {
        private const val TAG = "NotifyPilotFcm"
        private const val FIREBASE_MESSAGING_CLASS = "com.google.firebase.messaging.FirebaseMessaging"

        /**
         * Checks if Firebase Messaging is available at runtime.
         */
        fun isAvailable(): Boolean {
            return try {
                Class.forName(FIREBASE_MESSAGING_CLASS)
                true
            } catch (e: ClassNotFoundException) {
                false
            }
        }

        /**
         * Gets the FCM token via reflection. Calls [onResult] with the token or null on failure.
         */
        fun getToken(onResult: (String?) -> Unit) {
            if (!isAvailable()) {
                Log.w(TAG, "FirebaseMessaging not available. Skipping getToken.")
                onResult(null)
                return
            }

            try {
                val clazz = Class.forName(FIREBASE_MESSAGING_CLASS)
                val getInstance = clazz.getMethod("getInstance")
                val instance = getInstance.invoke(null)
                val getTokenMethod = clazz.getMethod("getToken")
                val task = getTokenMethod.invoke(instance)

                // task is a com.google.android.gms.tasks.Task<String>
                val taskClass = task!!.javaClass
                val addOnSuccessListener = taskClass.getMethod(
                    "addOnSuccessListener",
                    Class.forName("com.google.android.gms.tasks.OnSuccessListener")
                )
                val addOnFailureListener = taskClass.getMethod(
                    "addOnFailureListener",
                    Class.forName("com.google.android.gms.tasks.OnFailureListener")
                )

                // Create dynamic proxy for OnSuccessListener
                val successProxy = java.lang.reflect.Proxy.newProxyInstance(
                    clazz.classLoader,
                    arrayOf(Class.forName("com.google.android.gms.tasks.OnSuccessListener"))
                ) { _, _, args ->
                    onResult(args?.firstOrNull() as? String)
                    null
                }

                val failureProxy = java.lang.reflect.Proxy.newProxyInstance(
                    clazz.classLoader,
                    arrayOf(Class.forName("com.google.android.gms.tasks.OnFailureListener"))
                ) { _, _, _ ->
                    Log.e(TAG, "Failed to get FCM token")
                    onResult(null)
                    null
                }

                val taskWithSuccess = addOnSuccessListener.invoke(task, successProxy)
                addOnFailureListener.invoke(taskWithSuccess, failureProxy)
            } catch (e: Exception) {
                Log.e(TAG, "Error getting FCM token via reflection", e)
                onResult(null)
            }
        }

        /**
         * Subscribes to an FCM topic via reflection.
         */
        fun subscribeTopic(topic: String, onResult: (Boolean) -> Unit) {
            if (!isAvailable()) {
                Log.w(TAG, "FirebaseMessaging not available. Skipping subscribeTopic.")
                onResult(false)
                return
            }

            try {
                val clazz = Class.forName(FIREBASE_MESSAGING_CLASS)
                val getInstance = clazz.getMethod("getInstance")
                val instance = getInstance.invoke(null)
                val subscribeMethod = clazz.getMethod("subscribeToTopic", String::class.java)
                val task = subscribeMethod.invoke(instance, topic)

                addTaskListeners(clazz, task!!, { onResult(true) }, { onResult(false) })
            } catch (e: Exception) {
                Log.e(TAG, "Error subscribing to topic via reflection", e)
                onResult(false)
            }
        }

        /**
         * Unsubscribes from an FCM topic via reflection.
         */
        fun unsubscribeTopic(topic: String, onResult: (Boolean) -> Unit) {
            if (!isAvailable()) {
                Log.w(TAG, "FirebaseMessaging not available. Skipping unsubscribeTopic.")
                onResult(false)
                return
            }

            try {
                val clazz = Class.forName(FIREBASE_MESSAGING_CLASS)
                val getInstance = clazz.getMethod("getInstance")
                val instance = getInstance.invoke(null)
                val unsubscribeMethod = clazz.getMethod("unsubscribeFromTopic", String::class.java)
                val task = unsubscribeMethod.invoke(instance, topic)

                addTaskListeners(clazz, task!!, { onResult(true) }, { onResult(false) })
            } catch (e: Exception) {
                Log.e(TAG, "Error unsubscribing from topic via reflection", e)
                onResult(false)
            }
        }

        private fun addTaskListeners(
            firebaseClass: Class<*>,
            task: Any,
            onSuccess: () -> Unit,
            onFailure: () -> Unit
        ) {
            val taskClass = task.javaClass
            val addOnSuccessListener = taskClass.getMethod(
                "addOnSuccessListener",
                Class.forName("com.google.android.gms.tasks.OnSuccessListener")
            )
            val addOnFailureListener = taskClass.getMethod(
                "addOnFailureListener",
                Class.forName("com.google.android.gms.tasks.OnFailureListener")
            )

            val successProxy = java.lang.reflect.Proxy.newProxyInstance(
                firebaseClass.classLoader,
                arrayOf(Class.forName("com.google.android.gms.tasks.OnSuccessListener"))
            ) { _, _, _ ->
                onSuccess()
                null
            }

            val failureProxy = java.lang.reflect.Proxy.newProxyInstance(
                firebaseClass.classLoader,
                arrayOf(Class.forName("com.google.android.gms.tasks.OnFailureListener"))
            ) { _, _, _ ->
                onFailure()
                null
            }

            val taskWithSuccess = addOnSuccessListener.invoke(task, successProxy)
            addOnFailureListener.invoke(taskWithSuccess, failureProxy)
        }
    }
}
