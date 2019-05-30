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

static dispatch_queue_t _deallocCallbackQueueLock = NULL;

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

- (NSUInteger)addSelfCallback:(CYLDeallocSelfCallback)selfCallback
                   identifier:(NSInteger)identifier {
    //    static volatile int64_t globalIdentifier = 0;
    //    volatile int64_t a = self.globalIdentifier;
    if (!selfCallback) {
        return CYLDeallocCallbackIllegalIdentifier;
    }
    if (identifier > 0) {
        pthread_mutex_lock(&_lock);
        [_callbacksDictionary setObject:[selfCallback copy] forKey:@(identifier)];
        pthread_mutex_unlock(&_lock);
        return identifier;
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
    NSArray *sortedKeys = [[_callbacksDictionary allKeys] sortedArrayUsingSelector: @selector(compare:)];
    for (NSNumber *identifier in sortedKeys) {
        CYLDeallocSelfCallback block =  _callbacksDictionary[identifier];
        block(_owner, identifier.unsignedIntegerValue);
    }
    pthread_mutex_destroy(&_lock);
}

@end

//const void *CYLDeallocExecutorsKey = &CYLDeallocExecutorsKey;
@interface NSObject (CYLDeallocBlockExecutor)

@property (nonatomic, assign, getter=cyl_globalIdentifier, setter=cyl_setGlobalIdentifier:) NSInteger cyl_globalIdentifier;

@property (nonatomic, strong, getter=cyl_deallocCallbackQueue, setter=cyl_setDeallocCallbackQueue:) dispatch_queue_t cyl_deallocCallbackQueue;

@end

@implementation NSObject (CYLDeallocBlockExecutor)

- (NSInteger)cyl_globalIdentifier {
    NSNumber *globalIdentifierObject = objc_getAssociatedObject(self, @selector(cyl_globalIdentifier));
    return [globalIdentifierObject integerValue];
}

- (void)cyl_setGlobalIdentifier:(NSInteger)globalIdentifier {
    NSNumber *globalIdentifierObject = @(globalIdentifier);
    objc_setAssociatedObject(self, @selector(cyl_globalIdentifier), globalIdentifierObject, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSHashTable *)cyl_deallocExecutors {
    NSHashTable *table = objc_getAssociatedObject(self, @selector(cyl_deallocExecutors));
    if (!table) {
        table = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory];
        objc_setAssociatedObject(self, @selector(cyl_deallocExecutors), table, OBJC_ASSOCIATION_RETAIN);
    }
    return table;
}

- (void)cyl_executeAtDealloc:(CYLDeallocExecutorBlock)block {
    if (block) {
        CYLDeallocExecutor *executor = [[CYLDeallocExecutor alloc] initWithBlock:block];
        dispatch_sync(self.cyl_deallocCallbackQueue, ^{
            [[self cyl_deallocExecutors] addObject:executor];
        });
    }
}

- (void)cyl_setDeallocCallbackQueue:(dispatch_queue_t)deallocCallbackQueue {
    dispatch_queue_t deallocCallbackQueue_ = deallocCallbackQueue;
    objc_setAssociatedObject(self, @selector(cyl_deallocCallbackQueue), deallocCallbackQueue_, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (dispatch_queue_t)cyl_deallocCallbackQueue {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *queueBaseLabel = [NSString stringWithFormat:@"com.chengyilong.%@", NSStringFromClass([self class])];
        const char *queueName = [[NSString stringWithFormat:@"%@.deallocCallbackQueueLock", queueBaseLabel] UTF8String];
        _deallocCallbackQueueLock = dispatch_queue_create(queueName, DISPATCH_QUEUE_SERIAL);
    });
    __block dispatch_queue_t queue = nil;
    dispatch_sync(_deallocCallbackQueueLock, ^{
        dispatch_queue_t deallocCallbackQueue = objc_getAssociatedObject(self, @selector(cyl_deallocCallbackQueue));
        if (deallocCallbackQueue) {
            queue = deallocCallbackQueue;
        } else {
            NSString *queueBaseLabel = [NSString stringWithFormat:@"com.chenyilong.%@", NSStringFromClass([self class])];
            NSString *queueNameString = [NSString stringWithFormat:@"%@.forDeallocBlock.%@",queueBaseLabel, @(arc4random_uniform(MAXFLOAT))];
            const char *queueName = [queueNameString UTF8String];
            //因为用到了dispatch_barrier_async，该函数只能搭配自定义并行队列dispatch_queue_t使用。所以不能使用：dispatch_get_global_queue
            queue = dispatch_queue_create(queueName, DISPATCH_QUEUE_SERIAL);
            self.cyl_deallocCallbackQueue = queue;
        }
    });
    return queue;
}

- (NSUInteger)cyl_willDeallocWithSelfCallback:(CYLDeallocSelfCallback)selfCallback {
    if (!selfCallback) {
        return CYLDeallocCallbackIllegalIdentifier;
    }
    __block CYLDeallocCallbackModel *model = nil;
    __block NSInteger globalIdentifierBlockValue = self.cyl_globalIdentifier;
    dispatch_sync(self.cyl_deallocCallbackQueue, ^{
        globalIdentifierBlockValue = (self.cyl_globalIdentifier + 1);
        model = objc_getAssociatedObject(self, @selector(cyl_deallocExecutors));
        self.cyl_globalIdentifier = globalIdentifierBlockValue;
        if (!model) {
            model = [[CYLDeallocCallbackModel alloc] initWithOwner:self];
            objc_setAssociatedObject(self, @selector(cyl_deallocExecutors), model, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    });
    [model addSelfCallback:selfCallback identifier:globalIdentifierBlockValue];
    return globalIdentifierBlockValue;
}

- (BOOL)cyl_cancelDeallocCallbackWithIdentifier:(NSUInteger)identifier {
    CYLDeallocCallbackModel *model = objc_getAssociatedObject(self, @selector(cyl_deallocExecutors));
    if (model) {
        return [model removeCallbackWithIdentifier:identifier];
    }
    return NO;
}

- (void)cyl_cancelAllDeallocCallbacks {
    CYLDeallocCallbackModel *model = objc_getAssociatedObject(self, @selector(cyl_deallocExecutors));
    if (model) {
        [model removeAllCallbacks];
    }
}

@end
