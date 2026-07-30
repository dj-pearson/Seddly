import WidgetKit
import SwiftUI

/// US-171: entry point for the watch complication extension.
///
/// `SeddlyWatchComplication` previously lived inside the SeddlyWatch app target
/// with no `@main` bundle to host it. WidgetKit only discovers widgets declared
/// by a widget extension's principal bundle, so the complication compiled but
/// was never registered — it could not be added to a watch face. It now has its
/// own extension target, and this bundle is its entry point.
@main
struct SeddlyWatchComplicationBundle: WidgetBundle {
    var body: some Widget {
        SeddlyWatchComplication()
    }
}
