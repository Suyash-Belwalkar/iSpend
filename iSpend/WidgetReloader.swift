import Foundation
import WidgetKit

enum WidgetReloader {
    static let widgetKind = "iSpendWidget"

    static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
