//
//  AppDelegate.swift
//  v1.2.0
//  Created by 微博@iOS程序犭袁 ( http://weibo.com/luohanchenyilong/ ) on 15/12/27.
//  Copyright © 2015年 https://github.com/ChenYilong . All rights reserved.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let navBar = UINavigationBar.appearance()
        navBar.tintColor = .white
        navBar.titleTextAttributes = [.font: UIFont.boldSystemFont(ofSize: 18),
                                      .foregroundColor: UIColor.white]
        navBar.barTintColor = UIColor(red: 51 / 255, green: 171 / 255, blue: 160 / 255, alpha: 1)
        navBar.isTranslucent = false
        return true
    }
}
