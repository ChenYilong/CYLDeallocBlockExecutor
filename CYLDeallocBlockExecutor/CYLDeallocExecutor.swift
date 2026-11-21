//
//  CYLDeallocExecutor.swift
//  v1.2.0
//  Created by 微博@iOS程序犭袁 ( http://weibo.com/luohanchenyilong/ ) on 15/12/27.
//  Copyright © 2015年 https://github.com/ChenYilong . All rights reserved.
//

import Foundation

public typealias CYLDeallocExecutorBlock = () -> Void

/// Executes its block when it is deallocated.
public final class CYLDeallocExecutor: NSObject {

    private var deallocExecutorBlock: CYLDeallocExecutorBlock?

    public init(block: @escaping CYLDeallocExecutorBlock) {
        deallocExecutorBlock = block
        super.init()
    }

    deinit {
        deallocExecutorBlock?()
    }
}
