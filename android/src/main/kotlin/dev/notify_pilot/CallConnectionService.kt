package dev.notify_pilot

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.DisconnectCause
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager

/**
 * Android Telecom ConnectionService for proper system-level call management.
 * Integrates with the native phone UI and audio routing.
 */
class CallConnectionService : ConnectionService() {

    companion object {
        private const val PHONE_ACCOUNT_ID = "notify_pilot_calls"
        private const val PHONE_ACCOUNT_LABEL = "NotifyPilot Calls"

        /** Active connections keyed by callId. */
        val activeConnections = mutableMapOf<String, CallConnection>()

        /**
         * Registers a PhoneAccount with the system TelecomManager.
         * Must be called before placing or receiving calls through the Telecom framework.
         */
        fun registerPhoneAccount(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

            val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
                ?: return

            val componentName = ComponentName(context, CallConnectionService::class.java)
            val phoneAccountHandle = PhoneAccountHandle(componentName, PHONE_ACCOUNT_ID)

            val phoneAccount = PhoneAccount.builder(phoneAccountHandle, PHONE_ACCOUNT_LABEL)
                .setCapabilities(
                    PhoneAccount.CAPABILITY_CALL_PROVIDER
                        or PhoneAccount.CAPABILITY_CONNECTION_MANAGER
                )
                .addSupportedUriScheme(PhoneAccount.SCHEME_TEL)
                .addSupportedUriScheme(PhoneAccount.SCHEME_SIP)
                .build()

            telecomManager.registerPhoneAccount(phoneAccount)
        }

        /**
         * Returns the PhoneAccountHandle used by this service.
         */
        fun getPhoneAccountHandle(context: Context): PhoneAccountHandle {
            val componentName = ComponentName(context, CallConnectionService::class.java)
            return PhoneAccountHandle(componentName, PHONE_ACCOUNT_ID)
        }
    }

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        val extras = request?.extras ?: Bundle()
        val callId = extras.getString("callId", "")

        val connection = CallConnection(applicationContext, callId).apply {
            setInitializing()
            connectionCapabilities = Connection.CAPABILITY_MUTE or
                Connection.CAPABILITY_SUPPORT_HOLD or
                Connection.CAPABILITY_HOLD
            setCallerDisplayName(
                extras.getString("callerName", ""),
                android.telecom.TelecomManager.PRESENTATION_ALLOWED
            )
            val number = extras.getString("callerNumber", "")
            if (number.isNotEmpty()) {
                setAddress(Uri.parse("tel:$number"), TelecomManager.PRESENTATION_ALLOWED)
            }
            audioModeIsVoip = true
            setRinging()
        }

        activeConnections[callId] = connection
        return connection
    }

    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        val extras = request?.extras ?: Bundle()
        val callId = extras.getString("callId", "")

        val connection = CallConnection(applicationContext, callId).apply {
            setInitializing()
            connectionCapabilities = Connection.CAPABILITY_MUTE or
                Connection.CAPABILITY_SUPPORT_HOLD or
                Connection.CAPABILITY_HOLD
            audioModeIsVoip = true
            setDialing()
        }

        activeConnections[callId] = connection
        return connection
    }

    override fun onCreateIncomingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ) {
        val callId = request?.extras?.getString("callId", "") ?: ""
        sendCallBroadcast("dev.notify_pilot.CALL_FAILED", callId)
    }

    override fun onCreateOutgoingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ) {
        val callId = request?.extras?.getString("callId", "") ?: ""
        sendCallBroadcast("dev.notify_pilot.CALL_FAILED", callId)
    }

    private fun sendCallBroadcast(action: String, callId: String) {
        val intent = Intent(action).apply {
            putExtra("callId", callId)
            setPackage(applicationContext.packageName)
        }
        applicationContext.sendBroadcast(intent)
    }

    /**
     * Represents a single call connection within the Android Telecom framework.
     */
    class CallConnection(
        private val context: Context,
        private val callId: String
    ) : Connection() {

        override fun onAnswer() {
            setActive()
            sendCallBroadcast("dev.notify_pilot.CALL_ACCEPTED")
        }

        override fun onAnswer(videoState: Int) {
            setActive()
            sendCallBroadcast("dev.notify_pilot.CALL_ACCEPTED")
        }

        override fun onReject() {
            setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
            cleanup()
            sendCallBroadcast("dev.notify_pilot.CALL_DECLINED")
            destroy()
        }

        override fun onReject(rejectReason: Int) {
            setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
            cleanup()
            sendCallBroadcast("dev.notify_pilot.CALL_DECLINED")
            destroy()
        }

        override fun onDisconnect() {
            setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
            cleanup()
            sendCallBroadcast("dev.notify_pilot.CALL_ENDED")
            destroy()
        }

        override fun onHold() {
            setOnHold()
            sendCallBroadcast("dev.notify_pilot.CALL_HELD")
        }

        override fun onUnhold() {
            setActive()
            sendCallBroadcast("dev.notify_pilot.CALL_UNHELD")
        }

        override fun onPlayDtmfTone(c: Char) {
            // DTMF tone playing can be handled by the app layer
        }

        override fun onStopDtmfTone() {
            // DTMF tone stop can be handled by the app layer
        }

        private fun cleanup() {
            activeConnections.remove(callId)
        }

        private fun sendCallBroadcast(action: String) {
            val intent = Intent(context, CallActionReceiver::class.java).apply {
                this.action = action
                putExtra("callId", callId)
            }
            context.sendBroadcast(intent)
        }
    }
}
