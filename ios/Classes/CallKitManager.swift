import Foundation
import CallKit
import Flutter
import AVFoundation

/// Manages incoming and outgoing calls via CallKit.
/// Wraps CXProvider and CXCallController to report and control calls,
/// and forwards call lifecycle events back to Flutter via callback closures.
@available(iOS 13.0, *)
class CallKitManager: NSObject, CXProviderDelegate {

    // MARK: - Callbacks

    /// Called when the user accepts an incoming call.
    /// Parameters: (callId: String, callerName: String?, callerNumber: String?, extra: [String: Any]?)
    var onCallAccepted: ((String, String?, String?, [String: Any]?) -> Void)?

    /// Called when the user declines an incoming call.
    /// Parameters: (callId: String)
    var onCallDeclined: ((String) -> Void)?

    /// Called when a call ends (user or remote).
    /// Parameters: (callId: String, reason: String)
    var onCallEnded: ((String, String) -> Void)?

    /// Called when the user toggles mute on a call.
    /// Parameters: (callId: String, isMuted: Bool)
    var onCallMuted: ((String, Bool) -> Void)?

    /// Called when the user toggles hold on a call.
    /// Parameters: (callId: String, isOnHold: Bool)
    var onCallHeld: ((String, Bool) -> Void)?

    // MARK: - Properties

    private let provider: CXProvider
    private let callController = CXCallController()

    /// Stores metadata for active calls, keyed by UUID.
    private var callMetadata: [UUID: CallInfo] = [:]

    // MARK: - Call Info

    /// Metadata associated with an active call.
    struct CallInfo {
        let callerName: String?
        let callerNumber: String?
        let callType: String?
        let hasVideo: Bool
        let extra: [String: Any]?
        let startTime: Date
    }

    // MARK: - Init

    /// Creates a new CallKitManager with the given provider configuration.
    ///
    /// - Parameter appName: The localized name displayed on the call UI.
    init(appName: String = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "App") {
        let configuration: CXProviderConfiguration
        if #available(iOS 14.0, *) {
            configuration = CXProviderConfiguration()
        } else {
            configuration = CXProviderConfiguration(localizedName: appName)
        }
        configuration.supportsVideo = true
        configuration.maximumCallGroups = 1
        configuration.supportedHandleTypes = [.phoneNumber, .generic]
        configuration.includesCallsInRecents = true

        if let iconImage = UIImage(named: "CallKitIcon") {
            configuration.iconTemplateImageData = iconImage.pngData()
        }

        provider = CXProvider(configuration: configuration)

        super.init()

        provider.setDelegate(self, queue: nil)

        NSLog("[NotifyPilot] CallKitManager: Initialized with appName '\(appName)'")
    }

    deinit {
        provider.invalidate()
    }

    // MARK: - Incoming Call

    /// Reports an incoming call to the system via CallKit.
    ///
    /// - Parameters:
    ///   - callId: A unique string identifier for the call (converted to UUID).
    ///   - callerName: The display name of the caller.
    ///   - callerNumber: The phone number or handle of the caller.
    ///   - callType: The type of call (e.g., "audio", "video").
    ///   - hasVideo: Whether the call includes video.
    ///   - extra: Additional metadata to store with the call.
    ///   - completion: Called with true on success, false on failure.
    func reportIncomingCall(
        callId: String,
        callerName: String?,
        callerNumber: String?,
        callType: String? = "audio",
        hasVideo: Bool = false,
        extra: [String: Any]? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        guard let uuid = UUID(uuidString: callId) ?? createUUID(from: callId) else {
            NSLog("[NotifyPilot] CallKitManager: Invalid callId '\(callId)'")
            completion(false)
            return
        }

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(
            type: callerNumber != nil ? .phoneNumber : .generic,
            value: callerNumber ?? callerName ?? "Unknown"
        )
        update.localizedCallerName = callerName
        update.hasVideo = hasVideo
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = true
        update.supportsHolding = true

        // Store metadata before reporting
        callMetadata[uuid] = CallInfo(
            callerName: callerName,
            callerNumber: callerNumber,
            callType: callType,
            hasVideo: hasVideo,
            extra: extra,
            startTime: Date()
        )

        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            if let error = error {
                NSLog("[NotifyPilot] CallKitManager: Failed to report incoming call: \(error.localizedDescription)")
                self?.callMetadata.removeValue(forKey: uuid)
                completion(false)
            } else {
                NSLog("[NotifyPilot] CallKitManager: Reported incoming call '\(callId)' from '\(callerName ?? "Unknown")'")
                completion(true)
            }
        }
    }

    // MARK: - Outgoing Call

    /// Starts an outgoing call via CXCallController.
    ///
    /// - Parameters:
    ///   - callId: A unique string identifier for the call.
    ///   - callerName: The display name of the recipient.
    ///   - callerNumber: The phone number or handle of the recipient.
    ///   - callType: The type of call (e.g., "audio", "video").
    ///   - completion: Called with true on success, false on failure.
    func startOutgoingCall(
        callId: String,
        callerName: String?,
        callerNumber: String?,
        callType: String? = "audio",
        completion: @escaping (Bool) -> Void
    ) {
        guard let uuid = UUID(uuidString: callId) ?? createUUID(from: callId) else {
            NSLog("[NotifyPilot] CallKitManager: Invalid callId '\(callId)'")
            completion(false)
            return
        }

        let handle = CXHandle(
            type: callerNumber != nil ? .phoneNumber : .generic,
            value: callerNumber ?? callerName ?? "Unknown"
        )

        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        startCallAction.isVideo = (callType == "video")
        startCallAction.contactIdentifier = callerName

        // Store metadata
        callMetadata[uuid] = CallInfo(
            callerName: callerName,
            callerNumber: callerNumber,
            callType: callType,
            hasVideo: callType == "video",
            extra: nil,
            startTime: Date()
        )

        let transaction = CXTransaction(action: startCallAction)
        callController.request(transaction) { error in
            if let error = error {
                NSLog("[NotifyPilot] CallKitManager: Failed to start outgoing call: \(error.localizedDescription)")
                completion(false)
            } else {
                NSLog("[NotifyPilot] CallKitManager: Started outgoing call '\(callId)' to '\(callerName ?? "Unknown")'")
                completion(true)
            }
        }
    }

    // MARK: - Call State Updates

    /// Reports that an outgoing call has connected.
    ///
    /// - Parameter callId: The identifier of the call that connected.
    func setCallConnected(callId: String) {
        guard let uuid = UUID(uuidString: callId) ?? createUUID(from: callId) else {
            NSLog("[NotifyPilot] CallKitManager: Invalid callId '\(callId)'")
            return
        }

        provider.reportOutgoingCall(with: uuid, connectedAt: Date())
        NSLog("[NotifyPilot] CallKitManager: Call '\(callId)' connected")
    }

    /// Ends an active call via CXCallController.
    ///
    /// - Parameters:
    ///   - callId: The identifier of the call to end.
    ///   - completion: Called with true on success, false on failure.
    func endCall(callId: String, completion: @escaping (Bool) -> Void) {
        guard let uuid = UUID(uuidString: callId) ?? createUUID(from: callId) else {
            NSLog("[NotifyPilot] CallKitManager: Invalid callId '\(callId)'")
            completion(false)
            return
        }

        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)

        callController.request(transaction) { error in
            if let error = error {
                NSLog("[NotifyPilot] CallKitManager: Failed to end call: \(error.localizedDescription)")
                completion(false)
            } else {
                NSLog("[NotifyPilot] CallKitManager: Ended call '\(callId)'")
                completion(true)
            }
        }
    }

    /// Hides an incoming call UI by reporting the call as ended.
    ///
    /// - Parameters:
    ///   - callId: The identifier of the call to hide.
    ///   - reason: The reason the call ended (maps to CXCallEndedReason).
    func hideIncomingCall(callId: String, reason: CXCallEndedReason = .remoteEnded) {
        guard let uuid = UUID(uuidString: callId) ?? createUUID(from: callId) else {
            NSLog("[NotifyPilot] CallKitManager: Invalid callId '\(callId)'")
            return
        }

        provider.reportCall(with: uuid, endedAt: Date(), reason: reason)
        callMetadata.removeValue(forKey: uuid)
        NSLog("[NotifyPilot] CallKitManager: Hidden incoming call '\(callId)'")
    }

    // MARK: - Query

    /// Returns a list of active calls with their metadata.
    ///
    /// - Returns: An array of dictionaries containing call information.
    func getActiveCalls() -> [[String: Any]] {
        var result: [[String: Any]] = []

        for (uuid, info) in callMetadata {
            var callData: [String: Any] = [
                "callId": uuid.uuidString,
                "startTime": Int(info.startTime.timeIntervalSince1970 * 1000),
                "hasVideo": info.hasVideo,
            ]
            if let name = info.callerName {
                callData["callerName"] = name
            }
            if let number = info.callerNumber {
                callData["callerNumber"] = number
            }
            if let type = info.callType {
                callData["callType"] = type
            }
            if let extra = info.extra {
                callData["extra"] = extra
            }
            result.append(callData)
        }

        return result
    }

    // MARK: - CXProviderDelegate

    func providerDidReset(_ provider: CXProvider) {
        NSLog("[NotifyPilot] CallKitManager: Provider did reset")
        callMetadata.removeAll()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let uuid = action.callUUID
        let info = callMetadata[uuid]

        NSLog("[NotifyPilot] CallKitManager: Call answered '\(uuid.uuidString)'")

        configureAudioSession()

        onCallAccepted?(uuid.uuidString, info?.callerName, info?.callerNumber, info?.extra)

        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let uuid = action.callUUID
        let info = callMetadata[uuid]

        NSLog("[NotifyPilot] CallKitManager: Call ended '\(uuid.uuidString)'")

        // Determine if this was a decline (call never answered) or a hangup
        let reason: String
        if info != nil {
            reason = "ended"
        } else {
            reason = "declined"
        }

        onCallEnded?(uuid.uuidString, reason)
        callMetadata.removeValue(forKey: uuid)

        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        NSLog("[NotifyPilot] CallKitManager: Outgoing call started '\(action.callUUID.uuidString)'")

        configureAudioSession()

        // Notify the provider that the outgoing call has started connecting
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())

        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        let uuid = action.callUUID
        let isOnHold = action.isOnHold

        NSLog("[NotifyPilot] CallKitManager: Call '\(uuid.uuidString)' hold: \(isOnHold)")

        onCallHeld?(uuid.uuidString, isOnHold)

        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        let uuid = action.callUUID
        let isMuted = action.isMuted

        NSLog("[NotifyPilot] CallKitManager: Call '\(uuid.uuidString)' mute: \(isMuted)")

        onCallMuted?(uuid.uuidString, isMuted)

        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        NSLog("[NotifyPilot] CallKitManager: Audio session activated")
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        NSLog("[NotifyPilot] CallKitManager: Audio session deactivated")
    }

    // MARK: - Private Helpers

    /// Configures the AVAudioSession for voice chat.
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true, options: [])
            NSLog("[NotifyPilot] CallKitManager: Audio session configured for voice chat")
        } catch {
            NSLog("[NotifyPilot] CallKitManager: Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    /// Creates a deterministic UUID from an arbitrary string identifier.
    ///
    /// - Parameter string: The string to convert.
    /// - Returns: A UUID derived from the string, or nil if conversion fails.
    private func createUUID(from string: String) -> UUID? {
        // Use UUID v5 style: hash the string to create a deterministic UUID
        let data = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: 16)
        data.withUnsafeBytes { bytes in
            for (index, byte) in bytes.enumerated() {
                hash[index % 16] ^= byte
            }
        }
        // Set version and variant bits
        hash[6] = (hash[6] & 0x0F) | 0x50 // version 5
        hash[8] = (hash[8] & 0x3F) | 0x80 // variant

        let hexString = hash.map { String(format: "%02x", $0) }.joined()
        let formatted = "\(hexString.prefix(8))-\(hexString.dropFirst(8).prefix(4))-\(hexString.dropFirst(12).prefix(4))-\(hexString.dropFirst(16).prefix(4))-\(hexString.dropFirst(20).prefix(12))"
        return UUID(uuidString: formatted)
    }
}
