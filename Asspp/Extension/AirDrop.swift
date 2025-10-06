//
//  AirDrop.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/19.
//

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(AppKit) && !canImport(UIKit)
    import AppKit
#endif

@discardableResult
func AirDrop(
    items: [Any],
    excludedActivityTypes: [String]? = nil
) -> Bool {
    #if canImport(UIKit)
        guard let source = UIWindow.mainWindow?.rootViewController?.topMostController else {
            return false
        }
        let newView = UIView()
        source.view.addSubview(newView)
        newView.frame = .init(origin: .zero, size: .init(width: 10, height: 10))
        newView.center = .init(
            x: source.view.bounds.width / 2 - 5,
            y: source.view.bounds.height / 2 - 5
        )
        let vc = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        vc.excludedActivityTypes = excludedActivityTypes?.map(UIActivity.ActivityType.init(rawValue:))
        vc.popoverPresentationController?.sourceView = source.view
        vc.popoverPresentationController?.sourceRect = newView.frame
        source.present(vc, animated: true) {
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    newView.removeFromSuperview()
                }
            }
        }
        return true
    #endif

    #if canImport(AppKit) && !canImport(UIKit)
        guard let keyWindow = NSApp.windows.first(where: { $0.isKeyWindow }) else {
            return false
        }

        let sharingServicePicker = NSSharingServicePicker(items: items)
        sharingServicePicker.show(relativeTo: keyWindow.contentView!.bounds, of: keyWindow.contentView!, preferredEdge: .maxY)
        return true
    #endif

    #if !canImport(UIKit) && !canImport(AppKit)
        return false
    #endif
}

#if canImport(UIKit)
    extension UIWindow {
        static var mainWindow: UIWindow? {
            if let keyWindow = UIApplication
                .shared
                .value(forKey: "keyWindow") as? UIWindow
            {
                return keyWindow
            }
            // if apple remove this shit, we fall back to ugly solution
            let keyWindow = UIApplication
                .shared
                .connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .compactMap { $0 as? UIWindowScene }
                .first?
                .windows
                .filter(\.isKeyWindow)
                .first
            return keyWindow
        }
    }

    extension UIViewController {
        var topMostController: UIViewController? {
            var result: UIViewController? = self
            while true {
                if let next = result?.presentedViewController,
                   !next.isBeingDismissed,
                   next as? UISearchController == nil
                {
                    result = next
                    continue
                }
                if let tabBar = result as? UITabBarController,
                   let next = tabBar.selectedViewController
                {
                    result = next
                    continue
                }
                if let split = result as? UISplitViewController,
                   let next = split.viewControllers.last
                {
                    result = next
                    continue
                }
                if let navigator = result as? UINavigationController,
                   let next = navigator.viewControllers.last
                {
                    result = next
                    continue
                }
                break
            }
            return result
        }
    }
#endif
