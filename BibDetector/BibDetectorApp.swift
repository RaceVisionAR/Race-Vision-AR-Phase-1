//
//  BibDetectorApp.swift
//  BibDetector
//
//  Created by Alex Rabin on 3/16/26.
//

import FirebaseCore
import GoogleSignIn
import SwiftUI

@main
@MainActor
struct BibDetectorApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var appModel = AppModel()

    init() {
        FirebaseApp.configure()
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
    }

    var body: some Scene {
        WindowGroup {
            if authService.isSignedIn {
                ContentView()
                    .environmentObject(appModel)
                    .environmentObject(authService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
    }
}
