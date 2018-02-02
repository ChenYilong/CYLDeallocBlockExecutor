//
//  NSObject+CYLDeallocBlockExecutor.h
//  CYLDeallocBlockExecutor
//  v1.2.0
//  Created by 微博@iOS程序犭袁 ( http://weibo.com/luohanchenyilong/ ) on 15/12/27.
//  Copyright © 2015年 https://github.com/ChenYilong . All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CYLDeallocExecutor.h"

/**
 *  Dealloc task block definition.
 *
 *  - param owner     the self object
 *  - param identifier task identifier
 */
typedef void (^CYLDeallocSelfCallback)(__unsafe_unretained id owner, NSUInteger identifier);

/**
 *  illegal identifier.
 */
extern const NSUInteger CYLDeallocCallbackIllegalIdentifier;

@interface NSObject (CYLDeallocBlockExecutor)

/**
 *  Add dealloc callback to object.
 *
 *  @param selfCallback The dealloc task
 *
 *  @return The task identifier
 */
- (NSUInteger)cyl_willDeallocWithSelfCallback:(CYLDeallocSelfCallback)selfCallback;

/**
 *  Remove callback by identifier.
 *
 *  @param identifier The callback identifier
 *
 *  @return Remove success or not
 */
- (BOOL)cyl_cancelDeallocCallbackWithIdentifier:(NSUInteger)identifier;

/**
 *  Remove all dealloc callbacks.
 */
- (void)cyl_cancelAllDeallocCallbacks;

- (void)cyl_executeAtDealloc:(CYLDeallocExecutorBlock)block __attribute__((deprecated("Deprecated in 1.2.0. Use `-cyl_willDeallocWithSelfCallback:` instead.")));

@end

