package dev.notify_pilot

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class HistoryStore(context: Context) : SQLiteOpenHelper(context, DB_NAME, null, DB_VERSION) {

    companion object {
        private const val DB_NAME = "notify_pilot_history.db"
        private const val DB_VERSION = 1
        private const val TABLE = "notification_history"

        private const val COL_ID = "id"
        private const val COL_TITLE = "title"
        private const val COL_BODY = "body"
        private const val COL_CHANNEL_ID = "channel_id"
        private const val COL_GROUP_KEY = "group_key"
        private const val COL_DEEP_LINK = "deep_link"
        private const val COL_PAYLOAD = "payload"
        private const val COL_TIMESTAMP = "timestamp"
        private const val COL_STATUS = "status"
        private const val COL_ACTION_TAKEN = "action_taken"
        private const val COL_IS_READ = "is_read"
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE $TABLE (
                $COL_ID INTEGER PRIMARY KEY,
                $COL_TITLE TEXT,
                $COL_BODY TEXT,
                $COL_CHANNEL_ID TEXT,
                $COL_GROUP_KEY TEXT,
                $COL_DEEP_LINK TEXT,
                $COL_PAYLOAD TEXT,
                $COL_TIMESTAMP INTEGER,
                $COL_STATUS INTEGER DEFAULT 0,
                $COL_ACTION_TAKEN TEXT,
                $COL_IS_READ INTEGER DEFAULT 0
            )
            """.trimIndent()
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE")
        onCreate(db)
    }

    fun insert(
        id: Int,
        title: String?,
        body: String?,
        channelId: String?,
        groupKey: String?,
        deepLink: String?,
        payload: String?,
        timestamp: Long = System.currentTimeMillis(),
        status: Int = 0
    ) {
        val values = ContentValues().apply {
            put(COL_ID, id)
            put(COL_TITLE, title)
            put(COL_BODY, body)
            put(COL_CHANNEL_ID, channelId)
            put(COL_GROUP_KEY, groupKey)
            put(COL_DEEP_LINK, deepLink)
            put(COL_PAYLOAD, payload)
            put(COL_TIMESTAMP, timestamp)
            put(COL_STATUS, status)
            put(COL_IS_READ, 0)
        }
        writableDatabase.insertWithOnConflict(TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun query(limit: Int = 100, groupFilter: String? = null): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        val selection = if (groupFilter != null) "$COL_GROUP_KEY = ?" else null
        val selectionArgs = if (groupFilter != null) arrayOf(groupFilter) else null

        val cursor = readableDatabase.query(
            TABLE, null, selection, selectionArgs,
            null, null, "$COL_TIMESTAMP DESC", limit.toString()
        )

        cursor.use {
            while (it.moveToNext()) {
                val row = mutableMapOf<String, Any?>()
                row["id"] = it.getInt(it.getColumnIndexOrThrow(COL_ID))
                row["title"] = it.getString(it.getColumnIndexOrThrow(COL_TITLE))
                row["body"] = it.getString(it.getColumnIndexOrThrow(COL_BODY))
                row["channelId"] = it.getString(it.getColumnIndexOrThrow(COL_CHANNEL_ID))
                row["groupKey"] = it.getString(it.getColumnIndexOrThrow(COL_GROUP_KEY))
                row["deepLink"] = it.getString(it.getColumnIndexOrThrow(COL_DEEP_LINK))
                row["payload"] = it.getString(it.getColumnIndexOrThrow(COL_PAYLOAD))
                row["timestamp"] = it.getLong(it.getColumnIndexOrThrow(COL_TIMESTAMP))
                row["status"] = it.getInt(it.getColumnIndexOrThrow(COL_STATUS))
                row["actionTaken"] = it.getString(it.getColumnIndexOrThrow(COL_ACTION_TAKEN))
                row["isRead"] = it.getInt(it.getColumnIndexOrThrow(COL_IS_READ)) == 1
                results.add(row)
            }
        }
        return results
    }

    fun updateStatus(id: Int, status: Int, actionTaken: String? = null) {
        val values = ContentValues().apply {
            put(COL_STATUS, status)
            if (actionTaken != null) put(COL_ACTION_TAKEN, actionTaken)
        }
        writableDatabase.update(TABLE, values, "$COL_ID = ?", arrayOf(id.toString()))
    }

    fun markRead(id: Int) {
        val values = ContentValues().apply { put(COL_IS_READ, 1) }
        writableDatabase.update(TABLE, values, "$COL_ID = ?", arrayOf(id.toString()))
    }

    fun markAllRead() {
        val values = ContentValues().apply { put(COL_IS_READ, 1) }
        writableDatabase.update(TABLE, values, null, null)
    }

    fun clearAll() {
        writableDatabase.delete(TABLE, null, null)
    }

    fun clearOlderThan(timestampMillis: Long) {
        writableDatabase.delete(TABLE, "$COL_TIMESTAMP < ?", arrayOf(timestampMillis.toString()))
    }

    fun getUnreadCount(): Int {
        val cursor = readableDatabase.rawQuery(
            "SELECT COUNT(*) FROM $TABLE WHERE $COL_IS_READ = 0", null
        )
        cursor.use {
            return if (it.moveToFirst()) it.getInt(0) else 0
        }
    }
}
