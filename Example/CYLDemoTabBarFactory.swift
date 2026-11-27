//
//  CYLDemoTabBarFactory.swift
//  The Example's root: a CYLTabBarController. Home (the first tab) is the tag-list demo menu; the old log list
//  (ViewController) is assigned to the second tab, Log. CYLTabBarController is consumed as a pod pin only.
//

import UIKit
import CYLTabBarController

/// The tab positions of the Example.
enum CYLDemoTabs {
    /// The Log tab: the old log list, no longer the root screen.
    static let logIndex = 1
}

enum CYLDemoTabBarFactory {

    static func makeTabBarController() -> CYLTabBarController {
        let home = UINavigationController(rootViewController: CYLDemoMenuViewController())
        let log = UINavigationController(rootViewController: ViewController())
        // Two tabs, no plus button, so the even-count rule of the plus button does not apply.
        let attributes: [[AnyHashable: Any]] = [
            [cylTabBarItemTitle: "Home",
             cylTabBarItemImage: UIImage(systemName: "house") as Any,
             cylTabBarItemSelectedImage: UIImage(systemName: "house.fill") as Any],
            [cylTabBarItemTitle: "Log",
             cylTabBarItemImage: UIImage(systemName: "list.bullet.rectangle") as Any,
             cylTabBarItemSelectedImage: UIImage(systemName: "list.bullet.rectangle.fill") as Any]
        ]
        return CYLTabBarController(viewControllers: [home, log], tabBarItemsAttributes: attributes)
    }
}
