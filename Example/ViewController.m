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

@interface ViewController ()
{
    NSNumber *_number;
}

@property (nonatomic, assign, getter=isBySetter) BOOL bySetter;
@property (nonatomic, strong) NSNumber *aNumber;
@end

@implementation ViewController

- (void)dealloc
{
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.themeMap = @{ @"BackgroundColor" : @"randomColor" };
    self.bySetter = YES;
    // Do any additional setup after loading the view, typically from a nib.
    
    _number = @(5);
    self.aNumber = @(6);
    
    __weak typeof(self) weakSelf = self;
    __unsafe_unretained typeof(self) unsafeSelf = self;
    
    
    [self cyl_executeAtDealloc:^{
        __strong typeof(self) strongSelf = weakSelf;
        //NSNumber *n = strongSelf->_number; //会挂 weakSelf还是具有地址值,strongSelf为nil. (编译器不允许weakSelf->访问指针)
        
        NSNumber *n1 = weakSelf.aNumber;
        NSNumber *n2 = strongSelf.aNumber;
        NSLog(@"%@,%@", n1, n2); //(null),(null)  尝试读取实例变量,里面的变量均为nil了
        
        NSNumber *n3 = unsafeSelf.aNumber; //unsafeSelf也具有地址值
        NSLog(@"%@", n3);//(null)
        
    }];
}

- (void)didReceiveMemoryWarning {
    //模拟对self多次执行 `cyl_executeAtDealloc:` 方法
    [self cyl_executeAtDealloc:^{
        NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @"");
    }];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.bySetter = !self.bySetter;
    if (self.isBySetter) {
        self.view.themeMap = @{ @"BackgroundColor" : @"randomColor" };
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:kThemeDidChangeNotification object:nil userInfo:@{ @"BackgroundColor" : @"randomColor" }];
    }
    
    static int i = 0;
    if (i == 0) {
        [self.navigationController pushViewController:[ViewController new] animated:YES];
        i++;
    }
}

@end
