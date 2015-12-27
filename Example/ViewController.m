//
//  ViewController.m
//  CYLDeallocExecutor
//
//  Created by 微博@iOS程序犭袁 (http://weibo.com/luohanchenyilong/) on 15/12/27.
//  Copyright © 2015年 https://github.com/ChenYilong . All rights reserved.
//

#import "ViewController.h"
#import "UIView+ThemeManager.h"
#import "CYLDeallocBlockExecutor.h"

@interface ViewController ()

@property (nonatomic, assign, getter=isBySetter) BOOL bySetter;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.themeMap = @{ @"BackgroundColor" : @"randomColor" };
    self.bySetter = YES;
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.bySetter = !self.bySetter;
    if (self.isBySetter) {
        self.view.themeMap = @{ @"BackgroundColor" : @"randomColor" };
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:kThemeDidChangeNotification object:nil userInfo:@{ @"BackgroundColor" : @"randomColor" }];
    }
}

@end
