//
//  ViewController.swift
//  v1.2.0
//  Created by 微博@iOS程序犭袁 ( http://weibo.com/luohanchenyilong/ ) on 15/12/27.
//  Copyright © 2015年 https://github.com/ChenYilong . All rights reserved.
//

import UIKit
import CYLDeallocBlockExecutor

class ViewController: UITableViewController {

    private var _number: NSNumber?
    private var bySetter = false
    private var aNumber: NSNumber?
    // Not lazy: appending through a lazy getter copies the array, which made the 600 000 rows below quadratic.
    private var dataSource: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "CYLDeallocExecutor"
        view.themeMap = ["BackgroundColor": "randomColor"]
        bySetter = true
        _number = 5
        aNumber = 6

        cylWillDealloc { [weak self] owner, identifier in
            // During dealloc a weak reference is already nil.
            let n1 = self?.aNumber
            // The unretained owner still has an address, but its ivars are already torn down.
            let n3 = (owner.takeUnretainedValue() as? ViewController)?.aNumber
            NSLog("🔴类名与方法名：\(#function)（在第\(#line)行），tag：\(arc4random_uniform(UInt32.max)), 描述：顺序执行：\(identifier), \(String(describing: n1))")
            NSLog("🔴类名与方法名：\(#function)（在第\(#line)行），tag：\(arc4random_uniform(UInt32.max)), 描述：顺序执行：\(identifier) \(String(describing: n3))")
        }

        tableView.delegate = self

        // Lifecycle blocks: the owner arrives typed, so no capture of self is needed.
        cylAddLifecycleCallback(for: .viewWillAppear) { owner, identifier, info in
            owner.showInfo("viewWillAppear (animated: \(info.animated ?? false)). Task: \(identifier)")
        }
        // Once, at the end of the first layout pass (like CYLTabBarController's one-time layout block).
        cylAddLifecycleCallback(for: .viewDidLayoutSubviews, timing: .end, invokeOnce: true) { owner, _, _ in
            owner.tableViewScrollToBottom(animated: false)
        }
        // Re-apply the skin when the appearance (light / dark) changes.
        cylAddLifecycleCallback(for: .traitCollectionDidChange) { owner, _, info in
            guard owner.traitCollection.hasDifferentColorAppearance(comparedTo: info.previousTraitCollection) else { return }
            owner.view.themeMap = ["BackgroundColor": "randomColor"]
        }

        // Force object release
        autoreleasepool {
            let object = NSObject()
            for _ in 0..<100000 {
                for _ in 0..<3 {
                    // Add task
                    let identifier = object.cylWillDealloc { [weak self] object, identifier in
                        self?.showInfo("Object: \(object.takeUnretainedValue()) dealloc. Task: \(identifier)")
                    }
                    showInfo("Object: \(object) created. Task: \(identifier)")
                }
            }
        }

        tableView.reloadData()
        tableViewScrollToBottom(animated: true)
        tableView.tableFooterView = UIView()
    }

    private func tableViewScrollToBottom(animated: Bool) {
        let numberOfRows = tableView.numberOfRows(inSection: 0)
        if numberOfRows > 0 {
            tableView.scrollToRow(at: IndexPath(row: numberOfRows - 1, section: 0), at: .bottom, animated: animated)
        }
    }

    private func showInfo(_ info: String) {
        dataSource.append(info)
    }

    override func didReceiveMemoryWarning() {
        // 模拟对self多次执行 `cylWillDealloc` 方法
        cylWillDealloc { _, identifier in
            NSLog("🔴类名与方法名：\(#function)（在第\(#line)行），描述：顺序执行：\(identifier)")
        }
    }

    deinit {
        NSLog("🔴类名与方法名：\(#function)（在第\(#line)行），tag：\(arc4random_uniform(UInt32.max)), 描述：")
    }

    // MARK: - UITableViewDelegate

    private static var pushed = false

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        bySetter.toggle()
        if bySetter {
            view.themeMap = ["BackgroundColor": "randomColor"]
        } else {
            NotificationCenter.default.post(name: kThemeDidChangeNotification, object: nil,
                                            userInfo: ["BackgroundColor": "randomColor"])
        }
        if !ViewController.pushed {
            navigationController?.pushViewController(ViewController(), animated: true)
            ViewController.pushed = true
        }
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        dataSource.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.font = .systemFont(ofSize: 14)
        cell.textLabel?.text = dataSource[indexPath.row]
        return cell
    }
}
