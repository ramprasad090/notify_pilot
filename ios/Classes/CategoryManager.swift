import Foundation
import UserNotifications

/// Creates and registers UNNotificationCategory instances with action buttons.
@available(iOS 13.0, *)
class CategoryManager {

    private let center = UNUserNotificationCenter.current()
    private var registeredCategories = Set<UNNotificationCategory>()

    /// Registers a category for the given actions list.
    /// The category identifier is derived from the notification's categoryIdentifier field.
    ///
    /// Action maps are expected to have:
    /// - "id": String action identifier
    /// - "label": String button title
    /// - "input": Bool whether this is a text input action
    /// - "inputHint": String? placeholder text for input
    /// - "destructive": Bool whether the action is destructive
    /// - "foreground": Bool whether the action opens the app
    func registerCategory(identifier: String, actions: [[String: Any]]) {
        let unActions: [UNNotificationAction] = actions.map { actionMap in
            let actionId = actionMap["id"] as? String ?? ""
            let label = actionMap["label"] as? String ?? ""
            let isInput = actionMap["input"] as? Bool ?? false
            let inputHint = actionMap["inputHint"] as? String
            let isDestructive = actionMap["destructive"] as? Bool ?? false
            let isForeground = actionMap["foreground"] as? Bool ?? true

            var options: UNNotificationActionOptions = []
            if isDestructive { options.insert(.destructive) }
            if isForeground { options.insert(.foreground) }

            if isInput {
                return UNTextInputNotificationAction(
                    identifier: actionId,
                    title: label,
                    options: options,
                    textInputButtonTitle: label,
                    textInputPlaceholder: inputHint ?? ""
                )
            } else {
                return UNNotificationAction(
                    identifier: actionId,
                    title: label,
                    options: options
                )
            }
        }

        let category = UNNotificationCategory(
            identifier: identifier,
            actions: unActions,
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        registeredCategories.insert(category)
        center.setNotificationCategories(registeredCategories)
    }

    /// Generates a deterministic category identifier from a list of actions.
    /// Uses the sorted action IDs joined with underscores.
    func categoryIdentifier(for actions: [[String: Any]]) -> String {
        let ids = actions.compactMap { $0["id"] as? String }.sorted()
        return "notify_pilot_\(ids.joined(separator: "_"))"
    }
}
