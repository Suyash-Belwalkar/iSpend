import Combine
import SwiftUI
import UIKit

enum AppQuickAction: String {
    case addExpense = "me.suyash.belwalkar.iSpend.addExpense"
}

enum AppDeepLink {
    static let scheme = "ispend"
    static let addExpenseHost = "add-expense"

    static func action(for url: URL) -> AppQuickAction? {
        guard url.scheme?.lowercased() == scheme else { return nil }

        let host = url.host?.lowercased()
        let path = url.path.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if host == addExpenseHost || path == addExpenseHost {
            return .addExpense
        }

        return nil
    }
}

@MainActor
final class QuickActionRouter: ObservableObject {
    static let shared = QuickActionRouter()

    @Published private(set) var pendingAction: AppQuickAction?

    private init() {}

    func trigger(_ action: AppQuickAction) {
        pendingAction = action
    }

    func consume() -> AppQuickAction? {
        let action = pendingAction
        pendingAction = nil
        return action
    }
}

final class QuickActionAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.shortcutItems = [
            UIApplicationShortcutItem(
                type: AppQuickAction.addExpense.rawValue,
                localizedTitle: "Add Expense",
                localizedSubtitle: "Create a transaction quickly",
                icon: UIApplicationShortcutIcon(systemImageName: "plus.circle"),
                userInfo: nil
            )
        ]
        return true
    }
}

final class QuickActionSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let shortcutItem = connectionOptions.shortcutItem {
            handle(shortcutItem)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let handled = handle(shortcutItem)
        completionHandler(handled)
    }

    @discardableResult
    private func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard shortcutItem.type == AppQuickAction.addExpense.rawValue else { return false }
        DispatchQueue.main.async {
            QuickActionRouter.shared.trigger(.addExpense)
        }
        return true
    }
}
