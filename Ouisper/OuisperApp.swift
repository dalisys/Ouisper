//
//  OuisperApp.swift
//  Ouisper
//
//  Created by Masmoudi on 06.01.26.
//

import SwiftUI

@main
struct OuisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            SettingsView()
        }
        .windowResizability(.automatic)
    }
}
