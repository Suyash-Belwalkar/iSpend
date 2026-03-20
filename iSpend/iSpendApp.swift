//
//  iSpendApp.swift
//  iSpend
//
//  Created by Suyash on 3/19/26.
//

import SwiftData
import SwiftUI

@main
struct iSpendApp: App {
    @UIApplicationDelegateAdaptor(QuickActionAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(SharedPersistence.sharedModelContainer)
    }
}
