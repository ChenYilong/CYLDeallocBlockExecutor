//
//  ViewController.m
//  CYLDeallocExecutor
//
//  Created by 微博@iOS程序犭袁 ( http://weibo.com/luohanchenyilong/ ) on 15/12/27.
//  Copyright © 2015年 https://github.com/ChenYilong . All rights reserved.
//

#import "ViewController.h"
#import "UIView+ThemeManager.h"
#import "CYLDeallocBlockExecutor.h"
typedef void (^CYLDeallocDemoBlock)();
@interface ViewController ()

@property (nonatomic, assign, getter=isBySetter) BOOL bySetter;
@property (nonatomic, copy) CYLDeallocDemoBlock deallocDemoBlock;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.themeMap = @{ @"BackgroundColor" : @"randomColor" };
    self.bySetter = YES;
    // Do any additional setup after loading the view, typically from a nib.
    
    
   
}
- (void)didReceiveMemoryWarning {
    self.deallocDemoBlock = ^() {
        self;
    };
    [self cyl_executeAtDealloc:^{
        NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @"");
    }];
}
- (void)dealloc {
    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @"");
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
