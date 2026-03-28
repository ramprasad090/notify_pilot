package dev.notify_pilot

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Fullscreen Activity displayed over the lock screen for incoming calls.
 * Creates a simple programmatic layout without XML resources.
 */
class IncomingCallActivity : Activity() {

    private var callId: String = ""
    private var callerName: String = ""
    private var callerNumber: String = ""
    private var callerAvatar: String = ""
    private var callType: String = "audio"
    private var acceptText: String = "Accept"
    private var declineText: String = "Decline"

    private var hideCallReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Show over lock screen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Extract intent extras
        callId = intent.getStringExtra("callId") ?: ""
        callerName = intent.getStringExtra("callerName") ?: ""
        callerNumber = intent.getStringExtra("callerNumber") ?: ""
        callerAvatar = intent.getStringExtra("callerAvatar") ?: ""
        callType = intent.getStringExtra("callType") ?: "audio"
        acceptText = intent.getStringExtra("acceptText") ?: "Accept"
        declineText = intent.getStringExtra("declineText") ?: "Decline"

        setContentView(buildLayout())

        // Register receiver to auto-dismiss when the call is cancelled externally
        hideCallReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val targetCallId = intent.getStringExtra("callId")
                if (targetCallId == callId) {
                    finish()
                }
            }
        }
        val filter = IntentFilter("dev.notify_pilot.HIDE_CALL")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(hideCallReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(hideCallReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (hideCallReceiver != null) {
            try {
                unregisterReceiver(hideCallReceiver)
            } catch (_: Exception) {
                // Receiver may already be unregistered
            }
            hideCallReceiver = null
        }
    }

    // region Layout Builder

    private fun buildLayout(): View {
        val density = resources.displayMetrics.density

        // Root container
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(Color.parseColor("#1A1A2E"))
            setPadding(0, dp(80, density), 0, dp(60, density))
        }

        // Caller avatar placeholder (circle)
        val avatarSize = dp(100, density)
        val avatarView = View(this).apply {
            val circleDrawable = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#4A4A6A"))
                setSize(avatarSize, avatarSize)
            }
            background = circleDrawable
            layoutParams = LinearLayout.LayoutParams(avatarSize, avatarSize).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(24, density)
            }
        }
        root.addView(avatarView)

        // Caller name
        val nameView = TextView(this).apply {
            text = callerName
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(8, density)
            }
        }
        root.addView(nameView)

        // Caller number
        val numberView = TextView(this).apply {
            text = callerNumber
            setTextColor(Color.parseColor("#AAAAAA"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(12, density)
            }
        }
        root.addView(numberView)

        // Call type indicator
        val callTypeLabel = if (callType == "video") "Video Call" else "Audio Call"
        val typeView = TextView(this).apply {
            text = callTypeLabel
            setTextColor(Color.parseColor("#888888"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(60, density)
            }
        }
        root.addView(typeView)

        // Spacer to push buttons to bottom
        val spacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f
            )
        }
        root.addView(spacer)

        // Button container
        val buttonContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        // Decline button (red circle)
        val declineButton = buildCircleButton(
            text = declineText,
            bgColor = "#E74C3C",
            density = density
        ) {
            sendCallBroadcast("dev.notify_pilot.CALL_DECLINED")
            finish()
        }
        buttonContainer.addView(declineButton)

        // Spacer between buttons
        val btnSpacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(60, density), 1)
        }
        buttonContainer.addView(btnSpacer)

        // Accept button (green circle)
        val acceptButton = buildCircleButton(
            text = acceptText,
            bgColor = "#27AE60",
            density = density
        ) {
            sendCallBroadcast("dev.notify_pilot.CALL_ACCEPTED")
            finish()
        }
        buttonContainer.addView(acceptButton)

        root.addView(buttonContainer)

        return root
    }

    private fun buildCircleButton(
        text: String,
        bgColor: String,
        density: Float,
        onClick: () -> Unit
    ): LinearLayout {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }

        val btnSize = dp(64, density)
        val circleButton = View(this).apply {
            val circleDrawable = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor(bgColor))
                setSize(btnSize, btnSize)
            }
            background = circleDrawable
            layoutParams = LinearLayout.LayoutParams(btnSize, btnSize).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(8, density)
            }
            isClickable = true
            isFocusable = true
            setOnClickListener { onClick() }
        }
        container.addView(circleButton)

        val label = TextView(this).apply {
            this.text = text
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            gravity = Gravity.CENTER
        }
        container.addView(label)

        return container
    }

    // endregion

    // region Helpers

    private fun sendCallBroadcast(action: String) {
        val intent = Intent(this, CallActionReceiver::class.java).apply {
            this.action = action
            putExtra("callId", callId)
        }
        sendBroadcast(intent)
    }

    private fun dp(value: Int, density: Float): Int {
        return (value * density).toInt()
    }

    // endregion
}
