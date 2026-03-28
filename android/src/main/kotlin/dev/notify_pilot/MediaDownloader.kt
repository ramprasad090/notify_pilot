package dev.notify_pilot

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * Downloads and caches images from URLs for use in notifications.
 *
 * Uses an LRU cache to avoid redundant network requests for previously
 * downloaded images (e.g. large icons, BigPictureStyle images).
 */
object MediaDownloader {

    private val executor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())

    /** LRU cache holding up to 20 bitmaps, sized by byte count. */
    private val bitmapCache: LruCache<String, Bitmap> = run {
        // Use 1/8th of available memory for the cache
        val maxMemory = (Runtime.getRuntime().maxMemory() / 1024).toInt()
        val cacheSize = maxMemory / 8

        object : LruCache<String, Bitmap>(cacheSize) {
            override fun sizeOf(key: String, bitmap: Bitmap): Int {
                return bitmap.byteCount / 1024
            }
        }
    }

    /**
     * Downloads an image from the given URL on a background thread and
     * delivers the resulting Bitmap via the callback on the main thread.
     *
     * Returns a cached bitmap immediately if available.
     *
     * @param url The image URL to download
     * @param callback Called with the downloaded Bitmap, or null on failure
     */
    fun download(url: String, callback: (Bitmap?) -> Unit) {
        // Check cache first
        val cached = bitmapCache.get(url)
        if (cached != null) {
            callback(cached)
            return
        }

        executor.execute {
            val bitmap = downloadBitmap(url)
            if (bitmap != null) {
                bitmapCache.put(url, bitmap)
            }
            mainHandler.post {
                callback(bitmap)
            }
        }
    }

    /**
     * Downloads a bitmap synchronously. Intended for use on a background thread.
     *
     * @param url The image URL to download
     * @return The downloaded Bitmap, or null on failure
     */
    fun downloadSync(url: String): Bitmap? {
        val cached = bitmapCache.get(url)
        if (cached != null) return cached

        val bitmap = downloadBitmap(url)
        if (bitmap != null) {
            bitmapCache.put(url, bitmap)
        }
        return bitmap
    }

    /**
     * Clears the bitmap cache.
     */
    fun clearCache() {
        bitmapCache.evictAll()
    }

    // region Private helpers

    private fun downloadBitmap(url: String): Bitmap? {
        return try {
            var currentUrl = url
            var redirectCount = 0
            while (redirectCount < 5) {
                val connection = URL(currentUrl).openConnection() as HttpURLConnection
                connection.connectTimeout = 10_000
                connection.readTimeout = 10_000
                connection.instanceFollowRedirects = true
                connection.doInput = true
                connection.connect()

                val responseCode = connection.responseCode
                if (responseCode in 300..399) {
                    val location = connection.getHeaderField("Location")
                    connection.disconnect()
                    if (location != null) {
                        currentUrl = location
                        redirectCount++
                        continue
                    }
                    return null
                }

                val inputStream = connection.inputStream
                return BitmapFactory.decodeStream(inputStream).also {
                    inputStream.close()
                    connection.disconnect()
                }
            }
            null
        } catch (_: Exception) {
            null
        }
    }

    // endregion
}
