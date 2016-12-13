//
//  NSObject+CYLDeallocBlockExecutor.m
//  CYLDeallocBlockExecutor
//
//  Created by 微博@iOS程序犭袁 ( http://weibo.com/luohanchenyilong/ ) on 15/12/27.
//  Copyright © 2015年 https://github.com/ChenYilong . All rights reserved.
//

#import "NSObject+CYLDeallocBlockExecutor.h"
#import <objc/runtime.h>

const void * CYLDeallocExecutorBlockKey = &CYLDeallocExecutorBlockKey;

@implementation NSObject (CYLDeallocBlockExecutor)

- (void)cyl_executeAtDealloc:(CYLDeallocExecutorBlock)block {
    if (block && !objc_getAssociatedObject(self, CYLDeallocExecutorBlockKey)) {
        CYLDeallocExecutor *executor = [[CYLDeallocExecutor alloc] initWithBlock:block];
        objc_setAssociatedObject(self,
                                 CYLDeallocExecutorBlockKey,
                                 executor,
                                 OBJC_ASSOCIATION_RETAIN);
    }
}

@end
