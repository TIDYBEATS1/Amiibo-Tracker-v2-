//
//  Utilities.swift
//  AmiiboTracker
//
//  Created by Sam Stanwell on 08/07/2025.
//

import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

final class Utilities {
    
    static let shared = Utilities()
    
    private init() {}
    
    #if os(iOS)
    @MainActor
    class func topViewController(controller: UIViewController? = nil) -> UIViewController? {
        let controller = controller ?? UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
    #else
    /// macOS placeholder – not applicable
    class func topViewController() -> NSViewController? {
        return nil
    }
    #endif
}
