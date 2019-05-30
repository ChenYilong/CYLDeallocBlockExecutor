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
@property (nonatomic, strong) NSMutableArray *dataSource;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"CYLDeallocExecutor";
    self.view.themeMap = @{ @"BackgroundColor" : @"randomColor" };
    self.bySetter = YES;
    // Do any additional setup after loading the view, typically from a nib.
    _number = @(5);
    self.aNumber = @(6);
    __weak typeof(self) weakSelf = self;
    // __unsafe_unretained typeof(self) unsafeSelf = self;
    [self cyl_willDeallocWithSelfCallback:^(__unsafe_unretained typeof(self) unsafeSelf, NSUInteger identifier) {
        __strong typeof(self) strongSelf = weakSelf;
        // NSNumber *n = strongSelf->_number; //会挂， weakSelf 还是具有地址值,strongSelf为nil. (编译器不允许weakSelf->访问指针)
        NSNumber *n1 = weakSelf.aNumber;
        NSNumber *n2 = strongSelf.aNumber;
        NSLog(@"🔴类名与方法名：%@（在第%@行），tag：%@, 描述：顺序执行：%@, %@, %@", @(__PRETTY_FUNCTION__), @(__LINE__), @(arc4random_uniform(MAXFLOAT)), @(identifier), n1, n2); //(null),(null)  尝试读取实例变量,里面的变量均为nil了
        // NSLog(@"%@,%@", n1, n2); //(null),(null)  尝试读取实例变量,里面的变量均为nil了
        NSNumber *n3 = unsafeSelf.aNumber; //unsafeSelf也具有地址值
        NSLog(@"🔴类名与方法名：%@（在第%@行），tag：%@, 描述：顺序执行：%@ %@", @(__PRETTY_FUNCTION__), @(__LINE__), @(arc4random_uniform(MAXFLOAT)), @(identifier), n3);//(null)
    }];
    
    self.tableView.delegate = self;
    // Force object release
    
    
    @autoreleasepool {
        id object = [NSObject new];
        for (int i  = 0; i<100000; i++) {
        // Add task
        NSUInteger identifier1 = [object cyl_willDeallocWithSelfCallback:^(__unsafe_unretained id object, NSUInteger identifier) {
            [self showInfo:[NSString stringWithFormat:@"Object: %@ dealloc. Task: %ld", object, (unsigned long)identifier]];
        }];
        [self showInfo:[NSString stringWithFormat:@"Object: %@ created. Task: %ld", object, (unsigned long)identifier1]];

        // Add task
        NSUInteger identifier2 = [object cyl_willDeallocWithSelfCallback:^(__unsafe_unretained id object, NSUInteger identifier) {
            [self showInfo:[NSString stringWithFormat:@"Object: %@ dealloc. Task: %ld", object, (unsigned long)identifier]];
        }];
        [self showInfo:[NSString stringWithFormat:@"Object: %@ created. Task: %ld", object, (unsigned long)identifier2]];

        // Add task
        NSUInteger identifier3 = [object cyl_willDeallocWithSelfCallback:^(__unsafe_unretained id object, NSUInteger identifier) {
            [self showInfo:[NSString stringWithFormat:@"Object: %@ dealloc. Task: %ld", object, (unsigned long)identifier]];
        }];
        [self showInfo:[NSString stringWithFormat:@"Object: %@ created. Task: %ld", object, (unsigned long)identifier3]];

        // Remove task
//        [self showInfo:[NSString stringWithFormat:@"Object: %@ remove. Task: %ld", object, (unsigned long)identifier1]];
//        [object cyl_cancelDeallocCallbackWithIdentifier:identifier1];
        }
    }
    
    [self.tableView reloadData];
    [self tableViewScrollToBottomAnimated:YES];
    
    self.tableView.tableFooterView = [UIView new];
}

// 滑动到列表底部
- (void)tableViewScrollToBottomAnimated:(BOOL)animated {
    NSInteger numberOfRows = [self.tableView numberOfRowsInSection:0];
    if (numberOfRows) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:numberOfRows-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:animated];
    }
}

/**
 *  lazy load dataSource
 *
 *  @return NSMutableArray
 */
- (NSMutableArray *)dataSource {
    if (_dataSource == nil) {
        _dataSource = @[].mutableCopy;
    }
    return _dataSource;
}
- (void)showInfo:(NSString *)info {
    NSString *text = [NSString stringWithFormat:@"%@", info];
    [self.dataSource addObject:text];
}


- (void)didReceiveMemoryWarning {
    //模拟对self多次执行 `cyl_executeAtDealloc:` 方法
    [self cyl_willDeallocWithSelfCallback:^(__unsafe_unretained id unsafeSelf, NSUInteger identifier) {
        NSLog(@"🔴类名与方法名：%@（在第%@行），描述：顺序执行：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @(identifier));
    }];
}

//- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
//
//}

- (void)dealloc {
    NSLog(@"🔴类名与方法名：%@（在第%@行），tag：%@, 描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @(arc4random_uniform(MAXFLOAT)), @"");
}


#pragma mark -
#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
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

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:14.0f];
    }
    cell.textLabel.text = self.dataSource[indexPath.row];
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:14.0f];
    }
    cell.textLabel.text = @"222222";//self.dataSource[indexPath.row];
}

@end
