//
//  NSObject+CYLDeallocBlockExecutor.m
//  CYLDeallocBlockExecutor
//  v1.2.0
//  Created by 微博@iOS程序犭袁 ( http://weibo.com/luohanchenyilong/ ) on 15/12/27.
//  Copyright © 2015年 https://github.com/ChenYilong . All rights reserved.
//

#import "NSObject+CYLDeallocBlockExecutor.h"
#import <objc/runtime.h>
#include <libkern/OSAtomic.h>
#import <pthread.h>

static const char CYLDeallocCallbackModelKey;
static dispatch_queue_t _deallocCallbackQueue = 0;
const NSUInteger CYLDeallocCallbackIllegalIdentifier = 0;

@interface CYLDeallocCallbackModel : NSObject

@property (nonatomic, assign) pthread_mutex_t lock;
@property (nonatomic, strong) NSMutableDictionary *callbacksDictionary;
@property (nonatomic, unsafe_unretained) id owner;

@end

@implementation CYLDeallocCallbackModel

- (instancetype)initWithOwner:(id)owner {
    self = [super init];
    if (self) {
        _owner = owner;
        pthread_mutex_init(&_lock, NULL);
        _callbacksDictionary = [NSMutableDictionary new];
    }
    return self;
}

- (NSUInteger)addSelfCallback:(CYLDeallocSelfCallback)selfCallback {
    static volatile int64_t globalIdentifier = 0;
    if (!selfCallback) {
        return CYLDeallocCallbackIllegalIdentifier;
    }
    
    NSUInteger newIdentifier = (NSUInteger)OSAtomicIncrement64(&globalIdentifier);
    NSNumber *newIdentifierNumber = @(newIdentifier);
    
    if (newIdentifierNumber) {
        pthread_mutex_lock(&_lock);
        [_callbacksDictionary setObject:[selfCallback copy] forKey:newIdentifierNumber];
        pthread_mutex_unlock(&_lock);
        return newIdentifier;
    }
    return CYLDeallocCallbackIllegalIdentifier;
}

- (BOOL)removeCallbackWithIdentifier:(NSUInteger)identifier {
    if (identifier == CYLDeallocCallbackIllegalIdentifier) {
        return NO;
    }
    
    NSNumber *identifierNumber = [NSNumber numberWithUnsignedInteger:identifier];
    if (identifierNumber) {
        pthread_mutex_lock(&_lock);
        [_callbacksDictionary removeObjectForKey:identifierNumber];
        pthread_mutex_unlock(&_lock);
        return YES;
    }
    return NO;
}

- (void)removeAllCallbacks {
    pthread_mutex_lock(&_lock);
    [_callbacksDictionary removeAllObjects];
    pthread_mutex_unlock(&_lock);
}

- (void)dealloc {
    [_callbacksDictionary enumerateKeysAndObjectsUsingBlock:^(NSNumber *identifier, CYLDeallocSelfCallback block, BOOL * _Nonnull stop) {
        block(_owner, identifier.unsignedIntegerValue);
    }];
    pthread_mutex_destroy(&_lock);
}

@end

const void *CYLDeallocExecutorsKey = &CYLDeallocExecutorsKey;

@implementation NSObject (CYLDeallocBlockExecutor)

- (NSHashTable *)cyl_deallocExecutors {
    NSHashTable *table = objc_getAssociatedObject(self,CYLDeallocExecutorsKey);
    if (!table) {
        table = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory];
        objc_setAssociatedObject(self, CYLDeallocExecutorsKey, table, OBJC_ASSOCIATION_RETAIN);
    }
    return table;
}

- (void)cyl_executeAtDealloc:(CYLDeallocExecutorBlock)block {
    if (block) {
        CYLDeallocExecutor *executor = [[CYLDeallocExecutor alloc] initWithBlock:block];
        dispatch_sync(self.deallocCallbackQueue, ^{
            [[self cyl_deallocExecutors] addObject:executor];
        });
    }
}

- (dispatch_queue_t)deallocCallbackQueue {
    if (_deallocCallbackQueue == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _deallocCallbackQueue = dispatch_queue_create("com.chenyilong.CYLDeallocBlockExecutor.deallocCallbackQueue", DISPATCH_QUEUE_SERIAL);
        });
    }
    return _deallocCallbackQueue;
}

- (NSUInteger)cyl_willDeallocWithSelfCallback:(CYLDeallocSelfCallback)selfCallback {
    if (!selfCallback) {
        return CYLDeallocCallbackIllegalIdentifier;
    }
    __block CYLDeallocCallbackModel *model = nil;
    dispatch_sync(self.deallocCallbackQueue, ^{
        model = objc_getAssociatedObject(self, &CYLDeallocCallbackModelKey);
        if (!model) {
            model = [[CYLDeallocCallbackModel alloc] initWithOwner:self];
            objc_setAssociatedObject(self, &CYLDeallocCallbackModelKey, model, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    });
    NSUInteger newIdentifier = [model addSelfCallback:selfCallback];
    return newIdentifier;
}

- (BOOL)cyl_cancelDeallocCallbackWithIdentifier:(NSUInteger)identifier {
    CYLDeallocCallbackModel *model = objc_getAssociatedObject(self, &CYLDeallocCallbackModelKey);
    if (model) {
        return [model removeCallbackWithIdentifier:identifier];
    }
    return NO;
}

- (void)cyl_cancelAllDeallocCallbacks {
    CYLDeallocCallbackModel *model = objc_getAssociatedObject(self, &CYLDeallocCallbackModelKey);
    if (model) {
        [model removeAllCallbacks];
    }
}

@end
