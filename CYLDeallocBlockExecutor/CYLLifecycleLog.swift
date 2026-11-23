//
//  CYLLifecycleLog.swift
//  CYLDeallocBlockExecutor
//
//  Copyright © 2026 https://github.com/ChenYilong . All rights reserved.
//

import Foundation

/**
 * Debug log of the lifecycle moments (design v5). Off by default: turn it on while developing, read what fires on which owner,
 * in which order, and how many blocks ran. Messages are built lazily, so the disabled path costs one boolean check.
 *
 *     CYLLifecycleLog.isEnabled = true                           // prints through `sink`
 *     CYLLifecycleLog.sink = { message in os_log("%{public}@", message) }
 */
public enum CYLLifecycleLog {
    public static var isEnabled = false
    public static var sink: (String) -> Void = { print($0) }

    static func log(_ message: @autoclosure () -> String) {
        if isEnabled { sink("[CYLLifecycle] \(message())") }
    }

    /**
     * A short name for an owner: class name and address.
     */
    public static func describe(_ owner: AnyObject) -> String {
        "\(type(of: owner))@\(String(UInt(bitPattern: ObjectIdentifier(owner).hashValue), radix: 16))"
    }
}

/**
 * Well-known custom event names posted by the components (the library never posts them itself).
 */
public enum CYLAnimationEvent {
    public static let didStart = "cyl.animation.didStart"
    public static let didPause = "cyl.animation.didPause"
    public static let didResume = "cyl.animation.didResume"
    public static let didStop = "cyl.animation.didStop"
}

public enum CYLBadgeEvent {
    public static let didShow = "cyl.badge.didShow"
    public static let didClear = "cyl.badge.didClear"
    public static let didBecomeReady = "cyl.badge.didBecomeReady"
    public static let animationDidStart = "cyl.badge.animationDidStart"
    public static let animationDidStop = "cyl.badge.animationDidStop"
}
