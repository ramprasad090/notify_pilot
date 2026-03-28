import Foundation
import PushKit
import Flutter

/// Manages VoIP push notification registration via PushKit.
/// Implements PKPushRegistryDelegate to receive VoIP push tokens and
/// incoming push payloads, which must be reported to CallKit immediately
/// on iOS 13+ or the app will be terminated by the system.
@available(iOS 13.0, *)
class PushKitManager: NSObject, PKPushRegistryDelegate {

    // MARK: - Callbacks

    /// Called when the VoIP push token is updated.
    /// Parameter: (token: String) — the token as a hex string.
    var onTokenUpdate: ((String) -> Void)?

    /// Called when a VoIP push is received with call data.
    /// Parameters: (payload: [String: Any], completion: () -> Void)
    /// IMPORTANT: The completion handler MUST be called after reporting the call to CallKit.
    var onIncomingPush: (([String: Any], @escaping () -> Void) -> Void)?

    // MARK: - Properties

    private var pushRegistry: PKPushRegistry?
    private var currentToken: String?

    // MARK: - Registration

    /// Registers for VoIP push notifications.
    /// Creates a PKPushRegistry and sets the desired push types to VoIP.
    func register() {
        guard pushRegistry == nil else {
            NSLog("[NotifyPilot] PushKitManager: Already registered for VoIP pushes")
            return
        }

        let registry = PKPushRegistry(queue: DispatchQueue.main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        pushRegistry = registry

        NSLog("[NotifyPilot] PushKitManager: Registered for VoIP push notifications")
    }

    /// Returns the current VoIP push token as a hex string, or nil if not yet available.
    ///
    /// - Returns: The VoIP token string, or nil.
    func getVoIPToken() -> String? {
        return currentToken
    }

    // MARK: - PKPushRegistryDelegate

    /// Called when the VoIP push token is updated by the system.
    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        guard type == .voIP else { return }

        let token = pushCredentials.token
            .map { String(format: "%02x", $0) }
            .joined()

        currentToken = token

        NSLog("[NotifyPilot] PushKitManager: VoIP token updated (\(token.prefix(8))...)")

        onTokenUpdate?(token)
    }

    /// Called when a VoIP push notification is received.
    ///
    /// IMPORTANT: On iOS 13+, the app MUST report a call to CallKit within
    /// this method's completion handler. Failure to do so will cause the system
    /// to terminate the app. The `onIncomingPush` callback receives the payload
    /// and a completion closure that MUST be called after the CallKit report.
    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        guard type == .voIP else {
            completion()
            return
        }

        let payloadData = payload.dictionaryPayload as? [String: Any] ?? [:]

        NSLog("[NotifyPilot] PushKitManager: Received VoIP push with \(payloadData.count) keys")

        if let handler = onIncomingPush {
            handler(payloadData, completion)
        } else {
            // No handler registered — still must call completion.
            // Caller is responsible for ensuring CallKit is invoked before this point.
            NSLog("[NotifyPilot] PushKitManager: WARNING — No onIncomingPush handler. Completing without CallKit report.")
            completion()
        }
    }

    /// Called when the push token becomes invalid.
    func pushRegistry(
        _ registry: PKPushRegistry,
        didInvalidatePushTokenFor type: PKPushType
    ) {
        guard type == .voIP else { return }

        currentToken = nil
        NSLog("[NotifyPilot] PushKitManager: VoIP push token invalidated")
    }
}
