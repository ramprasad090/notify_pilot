import Foundation

/// Handles Firebase Cloud Messaging integration via runtime class lookup.
/// Does not require Firebase to be linked at compile time.
@available(iOS 13.0, *)
class FcmHandler {

    /// Returns `true` if Firebase Messaging is available at runtime.
    var isAvailable: Bool {
        return NSClassFromString("FIRMessaging") != nil
    }

    /// Gets the current FCM registration token.
    /// Returns `nil` if Firebase Messaging is not available.
    func getToken(completion: @escaping (String?) -> Void) {
        guard let messagingClass = NSClassFromString("FIRMessaging") as? NSObject.Type else {
            completion(nil)
            return
        }

        // FIRMessaging.messaging()
        let messagingSelector = NSSelectorFromString("messaging")
        guard messagingClass.responds(to: messagingSelector) else {
            completion(nil)
            return
        }

        guard let messaging = messagingClass.perform(messagingSelector)?.takeUnretainedValue() as? NSObject else {
            completion(nil)
            return
        }

        // messaging.tokenWithCompletion:
        let tokenSelector = NSSelectorFromString("tokenWithCompletion:")
        guard messaging.responds(to: tokenSelector) else {
            // Fallback: try reading the fcmToken property directly
            let fcmTokenSelector = NSSelectorFromString("FCMToken")
            if messaging.responds(to: fcmTokenSelector),
               let token = messaging.perform(fcmTokenSelector)?.takeUnretainedValue() as? String {
                completion(token)
            } else {
                completion(nil)
            }
            return
        }

        let callback: @convention(block) (String?, Error?) -> Void = { token, error in
            DispatchQueue.main.async {
                if let error = error {
                    NSLog("[NotifyPilot] FCM token error: \(error.localizedDescription)")
                }
                completion(token)
            }
        }

        messaging.perform(tokenSelector, with: callback)
    }

    /// Subscribes to an FCM topic.
    func subscribeTopic(_ topic: String, completion: @escaping (Bool) -> Void) {
        guard let messaging = getMessagingInstance() else {
            completion(false)
            return
        }

        let selector = NSSelectorFromString("subscribeToTopic:completion:")
        guard messaging.responds(to: selector) else {
            completion(false)
            return
        }

        let callback: @convention(block) (Error?) -> Void = { error in
            DispatchQueue.main.async {
                if let error = error {
                    NSLog("[NotifyPilot] FCM subscribe error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }

        let impl = messaging.method(for: selector)
        typealias Function = @convention(c) (AnyObject, Selector, NSString, Any) -> Void
        let function = unsafeBitCast(impl, to: Function.self)
        function(messaging, selector, topic as NSString, callback)
    }

    /// Unsubscribes from an FCM topic.
    func unsubscribeTopic(_ topic: String, completion: @escaping (Bool) -> Void) {
        guard let messaging = getMessagingInstance() else {
            completion(false)
            return
        }

        let selector = NSSelectorFromString("unsubscribeFromTopic:completion:")
        guard messaging.responds(to: selector) else {
            completion(false)
            return
        }

        let callback: @convention(block) (Error?) -> Void = { error in
            DispatchQueue.main.async {
                if let error = error {
                    NSLog("[NotifyPilot] FCM unsubscribe error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }

        let impl = messaging.method(for: selector)
        typealias Function = @convention(c) (AnyObject, Selector, NSString, Any) -> Void
        let function = unsafeBitCast(impl, to: Function.self)
        function(messaging, selector, topic as NSString, callback)
    }

    // MARK: - Private

    private func getMessagingInstance() -> NSObject? {
        guard let messagingClass = NSClassFromString("FIRMessaging") as? NSObject.Type else {
            return nil
        }
        let selector = NSSelectorFromString("messaging")
        guard messagingClass.responds(to: selector) else { return nil }
        return messagingClass.perform(selector)?.takeUnretainedValue() as? NSObject
    }
}
