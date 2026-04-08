//
//  BibDetectorApp.swift
//  BibDetector
//
//  Created by Alex Rabin on 3/16/26.
//

import FirebaseCore
import SwiftUI

@main
struct BibDetectorApp: App {
    init() {
        FirebaseApp.configure()
    }

    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
    }
}
