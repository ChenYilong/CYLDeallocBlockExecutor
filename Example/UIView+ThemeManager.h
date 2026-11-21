//
//  UIView+ThemeManager.h
//  CYLDeallocExecutor
//
//  Created by 微博@iOS程序犭袁 ( http://weibo.com/luohanchenyilong/ ) on 15/12/27.
//  Copyright © 2015年 https://github.com/ChenYilong . All rights reserved.
//

#import <UIKit/UIKit.h>

static NSString * const kThemeDidChangeNotification = @"ThemeDidChangeNotification";

@interface UIView (ThemeManager)

@property (nonatomic, readwrite, copy) NSDictionary *themeMap;

@end
