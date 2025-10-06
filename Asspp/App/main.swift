//
//  main.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

import ApplePackage
import Digger
import Logging
import SwiftUI

let logger = {
    var logger = Logger(label: "wiki.qaq.asspp")
    logger.logLevel = .debug
    return logger
}()

let version = [
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
]
.compactMap { $0 ?? "?" }
.joined(separator: ".")

let bundleIdentifier = Bundle.main.bundleIdentifier!
logger.info("Asspp \(bundleIdentifier) \(version) starting up...")

private let availableDirectories = FileManager
    .default
    .urls(for: .documentDirectory, in: .userDomainMask)
let documentsDirectory = availableDirectories[0]
    .appendingPathComponent("Asspp")
do {
    let enumerator = FileManager.default.enumerator(atPath: documentsDirectory.path)
    while let file = enumerator?.nextObject() as? String {
        let path = documentsDirectory.appendingPathComponent(file)
        if let content = try? FileManager.default.contentsOfDirectory(atPath: path.path),
           content.isEmpty
        { try? FileManager.default.removeItem(at: path) }
    }
}

try? FileManager.default.createDirectory(
    at: documentsDirectory,
    withIntermediateDirectories: true,
    attributes: nil
)
let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent(bundleIdentifier)
do {
    let enumerator = FileManager.default.enumerator(atPath: temporaryDirectory.path)
    while let file = enumerator?.nextObject() as? String {
        let path = temporaryDirectory.appendingPathComponent(file)
        if let content = try? FileManager.default.contentsOfDirectory(atPath: path.path),
           content.isEmpty
        { try? FileManager.default.removeItem(at: path) }
    }
}

try? FileManager.default.createDirectory(
    at: temporaryDirectory,
    withIntermediateDirectories: true,
    attributes: nil
)

_ = ProcessInfo.processInfo.hostName

DiggerManager.shared.maxConcurrentTasksCount = 3
DiggerManager.shared.startDownloadImmediately = true

#if os(iOS)
    Task.detached {
        _ = try await Installer(certificateAtPath: Installer.ca.path)
    }
#endif

App.main()

#if canImport(UIKit)
    import UIKit

    class AppDelegate: NSObject, UIApplicationDelegate {
        var taskIdentifier: UIBackgroundTaskIdentifier = .invalid

        func applicationWillResignActive(_: UIApplication) {
            let task = UIApplication.shared.beginBackgroundTask(withName: "Install Service") {}
            taskIdentifier = task
        }

        func applicationWillEnterForeground(_: UIApplication) {
            UIApplication.shared.endBackgroundTask(taskIdentifier)
        }
    }
#endif

#if canImport(AppKit) && !canImport(UIKit)
    import AppKit

    class AppDelegate: NSObject, NSApplicationDelegate {
        func applicationWillResignActive(_ notification: Notification) {
            // Handle app going to background on macOS
        }

        func applicationDidBecomeActive(_ notification: Notification) {
            // Handle app coming to foreground on macOS
            if let mainWindow = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "main-window" }) {
                mainWindow.styleMask = [.titled, .closable, .fullSizeContentView, .fullScreen]
            }
        }
    }
#endif

private struct App: SwiftUI.App {
    #if canImport(UIKit)
        @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    #if canImport(AppKit) && !canImport(UIKit)
        @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup(id: "main-window") {
            #if os(macOS)
                MainView()
                    .frame(minWidth: 900, minHeight: 600)
            #else
                if #available(iOS 26.0, *) {
                    NewMainView()
                } else {
                    MainView()
                }
            #endif
        }
    }
}
