//
//  CustomTabBarController.swift
//  v1.2.0
//  Created by 微博@iOS程序犭袁 ( http://weibo.com/luohanchenyilong/ ) on 15/12/27.
//  Copyright © 2015年 https://github.com/ChenYilong . All rights reserved.
//

import UIKit
import CYLTabBarController

class CustomTabBarController: CYLTabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllers()
    }

    private func setupViewControllers() {
        let vc1 = UIViewController()
        vc1.view.backgroundColor = .blue

        let vc2 = UIViewController()
        vc2.view.backgroundColor = .lightGray

        // 设置TabBarItem样式
        setUpTabBarItemsAttributesForController()

        setViewControllers([vc1, vc2])
    }

    private func setUpTabBarItemsAttributesForController() {
        let dict1 = [CYLTabBarItemTitle: "VC1", CYLTabBarItemImage: "", CYLTabBarItemSelectedImage: ""]
        let dict2 = [CYLTabBarItemTitle: "VC2", CYLTabBarItemImage: "", CYLTabBarItemSelectedImage: ""]
        tabBarItemsAttributes = [dict1, dict2]
    }
}
