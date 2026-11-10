import SwiftUI

@main
struct YusrApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
