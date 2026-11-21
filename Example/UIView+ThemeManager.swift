//
//  UIView+ThemeManager.swift
//  v1.2.0
//  Created by 微博@iOS程序犭袁 ( http://weibo.com/luohanchenyilong/ ) on 15/12/27.
//  Copyright © 2015年 https://github.com/ChenYilong . All rights reserved.
//

import UIKit
import ObjectiveC

let kThemeDidChangeNotification = Notification.Name("ThemeDidChangeNotification")

private var themeMapKey: UInt8 = 0

extension UIView {

    var themeMap: [String: Any]? {
        get { objc_getAssociatedObject(self, &themeMapKey) as? [String: Any] }
        set {
            objc_setAssociatedObject(self, &themeMapKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
            if let themeMap = newValue {
                // Need to removeObserver at dealloc.
                // NOTE: owner is unretained because a weak reference is already nil during dealloc.
                cyl_willDealloc { owner, identifier in
                    NSLog("🔴类名与方法名：\(#function)（在第\(#line)行），描述：顺序执行：\(identifier)")
                    NotificationCenter.default.removeObserver(owner.takeUnretainedValue())
                }
                NotificationCenter.default.removeObserver(self, name: kThemeDidChangeNotification, object: nil)
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(themeChanged(_:)),
                                                       name: kThemeDidChangeNotification,
                                                       object: nil)
                themeChanged(with: themeMap)
            } else {
                NotificationCenter.default.removeObserver(self, name: kThemeDidChangeNotification, object: nil)
            }
        }
    }

    @objc private func themeChanged(_ notification: Notification) {
        guard let themeMap = notification.userInfo as? [String: Any] else { return }
        themeChanged(with: themeMap)
    }

    private func themeChanged(with themeMap: [String: Any]) {
        if themeMap["BackgroundColor"] as? String == "randomColor" {
            backgroundColor = UIColor(red: CGFloat(arc4random_uniform(256)) / 255,
                                      green: CGFloat(arc4random_uniform(256)) / 255,
                                      blue: CGFloat(arc4random_uniform(256)) / 255,
                                      alpha: 1)
        }
    }
}
