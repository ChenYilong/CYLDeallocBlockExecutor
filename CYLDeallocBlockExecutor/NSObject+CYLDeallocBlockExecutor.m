//
//  NSObject+CYLDeallocBlockExecutor.m
//  CYLDeallocBlockExecutor
//
//  Created by 微博@iOS程序犭袁 (http://weibo.com/luohanchenyilong/) on 15/12/27.
//  Copyright © 2015年 https://github.com/ChenYilong . All rights reserved.
//

#import "NSObject+CYLDeallocBlockExecutor.h"
#import <objc/runtime.h>

const void * deallocExecutorBlockKey = &deallocExecutorBlockKey;

@implementation NSObject (CYLDeallocBlockExecutor)

- (void)cyl_executeAtDealloc:(DeallocExecutorBlock)block {
    if (block) {
        CYLDeallocExecutor *executor = [[CYLDeallocExecutor alloc] initWithBlock:block];
        objc_setAssociatedObject(self,
                                 deallocExecutorBlockKey,
                                 executor,
                                 OBJC_ASSOCIATION_RETAIN);
    }
}

@end
