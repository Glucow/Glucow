//
//  GlucowApp.swift
//  Glucow
//

import SwiftUI

@main
struct GlucowApp: App {
    @AppStorage("enableDarkMode") var enableDarkMode: Bool = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(enableDarkMode ? .dark : .light)
        }
    }
}
