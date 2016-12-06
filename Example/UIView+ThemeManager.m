//
//  UIView+ThemeManager.m
//  CYLDeallocExecutor
//
//  Created by 微博@iOS程序犭袁 ( http://weibo.com/luohanchenyilong/ ) on 15/12/27.
//  Copyright © 2015年 https://github.com/ChenYilong . All rights reserved.
//

#import "UIView+ThemeManager.h"
#import <objc/runtime.h>
#import "CYLDeallocBlockExecutor.h"

const void * kUIView_ThemeMap = &kUIView_ThemeMap;
const void * kUIView_DeallocHelper = &kUIView_DeallocHelper;

@implementation UIView (ThemeManager)

- (void)setThemeMap:(NSDictionary *)themeMap {
    objc_setAssociatedObject(self, &kUIView_ThemeMap, themeMap, OBJC_ASSOCIATION_COPY_NONATOMIC);
    if (themeMap) {
        // Need to removeObserver in dealloc
        // NOTE: need to be __unsafe_unretained because __weak var will be reset to nil in dealloc
        __unsafe_unretained __typeof(self) weakSelf = self;
        [self cyl_executeAtDealloc:^{
            [[NSNotificationCenter defaultCenter] removeObserver:weakSelf];
        }];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:kThemeDidChangeNotification
                                                      object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(themeChanged:)
                                                     name:kThemeDidChangeNotification
                                                   object:nil
         ];
        [self themeChangedWithDict:themeMap];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:kThemeDidChangeNotification
                                                      object:nil];
    }
}

- (NSDictionary *)themeMap {
    return objc_getAssociatedObject(self, @selector(themeMap));
}

- (void)themeChanged:(NSNotification *)notification {
        if (notification.userInfo == nil) {
            return;
        }
    NSDictionary *themeMap = [notification userInfo];
    [self themeChangedWithDict:themeMap];
}

- (void)themeChangedWithDict:(NSDictionary *)themeMap {
    if ([themeMap[@"BackgroundColor"] isEqualToString:@"randomColor"]) {
        self.backgroundColor = [UIColor colorWithRed:arc4random_uniform(256) / 255.f
                                               green:arc4random_uniform(256) / 255.f
                                                blue:arc4random_uniform(256) / 255.f
                                               alpha:1.f
                                ];
    }
}

@end

// 如果不使用CYLDeallocBlockExecutor，则代码如下所示：


//- (void)setThemeMap:(NSDictionary *)themeMap {
//    objc_setAssociatedObject(self, &kUIView_ThemeMap, themeMap, OBJC_ASSOCIATION_COPY_NONATOMIC);
//    if (themeMap) {
//        // Need to removeObserver in dealloc
//        if (objc_getAssociatedObject(self, &kUIView_DeallocHelper) == nil) {
//            // NOTE: need to be __unsafe_unretained because __weak var will be reset to nil in dealloc
//            __unsafe_unretained __typeof(self) weakSelf = self;
//            id deallocHelper = [self addDeallocBlock:^{
//                [[NSNotificationCenter defaultCenter] removeObserver:weakSelf];
//            }];
//            objc_setAssociatedObject(self, &kUIView_DeallocHelper, deallocHelper, OBJC_ASSOCIATION_ASSIGN);
//        }
//        [[NSNotificationCenter defaultCenter] removeObserver:self name:kThemeDidChangeNotification object:nil];
//        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged)
//                                                     name:kThemeDidChangeNotification object:nil];
//        [self themeChanged];
//    }
//    else {
//        [[NSNotificationCenter defaultCenter] removeObserver:self name:kThemeDidChangeNotification object:nil];
//    }
//}