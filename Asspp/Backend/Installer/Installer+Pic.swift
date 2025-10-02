//
//  Installer+Pic.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(AppKit) && !canImport(UIKit)
    import AppKit
#endif

extension Installer {
    func createWhite(_ r: CGFloat) -> Data {
        #if canImport(UIKit)
            let renderer = UIGraphicsImageRenderer(size: .init(width: r, height: r))
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(.init(x: 0, y: 0, width: r, height: r))
            }
            return image.pngData()!
        #endif

        #if canImport(AppKit) && !canImport(UIKit)
            let image = NSImage(size: .init(width: r, height: r))
            image.lockFocus()
            NSColor.white.set()
            NSRect(x: 0, y: 0, width: r, height: r).fill()
            image.unlockFocus()

            guard let tiffRepresentation = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffRepresentation)
            else {
                return Data()
            }
            return bitmap.representation(using: .png, properties: [:]) ?? Data()
        #endif

        #if !canImport(UIKit) && !canImport(AppKit)
            return Data()
        #endif
    }
}
