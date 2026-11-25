//
//  SceneDelegate.swift
//  CYLDeallocBlockExecutor
//  Created by ChenYilong on 2026-11-22.
//

import UIKit

/// The scene life cycle the Example needs: iOS 27 stops launching apps without `UIApplicationSceneManifest`.
@objc(CYLExampleSceneDelegate)
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = CYLDemoTabBarFactory.makeTabBarController()
        window.backgroundColor = .white
        window.makeKeyAndVisible()
        self.window = window
    }
}
