//
//  CustomTabBarController.m
//  TestDemo
//
//  Created by qianxx on 16/7/6.
//  Copyright © 2016年 pby. All rights reserved.
//

#import "CustomTabBarController.h"

@interface CustomTabBarController ()

@end

@implementation CustomTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self settupViewControllers];
}


- (void)settupViewControllers
{
    UIViewController *vc1 = [UIViewController new];
    vc1.view.backgroundColor = [UIColor blueColor];
    
    UIViewController *vc2 = [UIViewController new];
    vc2.view.backgroundColor = [UIColor lightGrayColor];
    
    //设置TabBarItem样式
    [self setUpTabBarItemsAttributesForController];
    
    [self setViewControllers:@[vc1, vc2]];
}


///设置TabBarItem样式
- (void)setUpTabBarItemsAttributesForController
{
    NSDictionary *dict1 = @{
                            CYLTabBarItemTitle : @"VC1",
                            CYLTabBarItemImage : @"",
                            CYLTabBarItemSelectedImage : @"",
                            };

     NSDictionary *dict2 = @{
                             CYLTabBarItemTitle : @"VC2",
                             CYLTabBarItemImage : @"",
                             CYLTabBarItemSelectedImage : @"",
                             };

    NSArray *tabBarItemsAttributes = @[dict1,dict2];
    self.tabBarItemsAttributes = tabBarItemsAttributes;
}



@end




