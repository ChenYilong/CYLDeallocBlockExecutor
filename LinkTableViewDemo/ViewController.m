//
//  ViewController.m
//  LinkTableViewDemo
//
//  Created by chenyilong on 15/3/26.
//  Copyright (c) 2015年 chenyilong. All rights reserved.
//  特点：⓵高度由 kLinkTextFontSize 和 kLinkCellsMargin决定，⓶cells 间距由kLinkCellsMargin决定

#import "ViewController.h"
#import "ColorLinkCell.h"
#import "NSMutableAttributedString+Common.h"
#import "NSString+Size.h"

#define kLinkCellsMargin 8
#define kLinkText @"linkText"
#define kLinkURL @"url"
#define kNormalText @"normalText"

#define kLinkTextColor [UIColor colorWithRed:243/255.0 green:100/255.0 blue:21/255.0 alpha:1]
#define kNormalTextColor [UIColor blackColor]
#define kLinkTextFontSize 20
#define kLinkTextFont [UIFont systemFontOfSize:kLinkTextFontSize]
#define kNormalTextFont kLinkTextFont

#define kDataSourceSectionKey @"Symptoms"
#define kDataSourceCellTextKey @"Patient_Name"
#define kDataSourceLinkTextKey @"Doctor_Name"
#define kDataSourceCellPictureKey @"Picture"

@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, strong) NSMutableArray *dataSource;
@property (nonatomic, copy) NSString *string;
@property (nonatomic) BOOL *isCellSelected;
@property (nonatomic, strong) NSMutableAttributedString *mutableAttributedString;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UITableView *tableView = [[UITableView alloc] init];
    tableView.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.delegate = self;
    tableView.dataSource = self;
    [self initData];
    [self.view addSubview:tableView];
}

- (NSMutableArray *)dataSource
{
    if (_dataSource == nil) {
        _dataSource = [[NSMutableArray alloc] init];
    }
    return _dataSource;
}

- (void)initData {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"data" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    NSArray *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
    self.dataSource = [NSMutableArray arrayWithArray:json];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.dataSource count];
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    float contentHeight = [NSString getHeighthWithSystemFontSize:kLinkTextFontSize];
    return contentHeight+kLinkCellsMargin;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *symptoms = [NSArray arrayWithArray:[self.dataSource[section] objectForKey:kDataSourceSectionKey]];
    return [symptoms count];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *symptoms = [NSMutableArray arrayWithArray:[self.dataSource[indexPath.section] objectForKey:kDataSourceSectionKey]];
    NSString *normaltext = [symptoms[indexPath.row] objectForKey:kDataSourceCellTextKey];
    NSString *linkText = [symptoms[indexPath.row] objectForKey:kDataSourceLinkTextKey];
    NSString *urlText = [symptoms[indexPath.row] objectForKey:kDataSourceCellPictureKey];
    
    NSMutableAttributedString *linkAttributedString = [[NSMutableAttributedString alloc] init];
    if (urlText.length >0) {
        linkAttributedString = [linkAttributedString convertToLinkStringWithString:linkText color:kLinkTextColor font:kLinkTextFont];
    } else {
        linkAttributedString = [linkAttributedString initWithString:linkText];
    }
    NSMutableAttributedString *normalAttributedString = [[NSMutableAttributedString alloc] initWithString:normaltext];
    [linkAttributedString appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"，"]];
    [linkAttributedString appendAttributedString:normalAttributedString];
    ColorLinkCell *cell = [ColorLinkCell cellWithTableView:tableView];
    cell.textLabel.font = kLinkTextFont;
    [cell.textLabel setAttributedText:linkAttributedString];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}


- (void)tableView:(UITableView *)tableView didHighlightRowAtIndexPath:(NSIndexPath *)indexPath  {
   
    NSMutableArray *symptoms = [NSMutableArray arrayWithArray:[self.dataSource[indexPath.section] objectForKey:kDataSourceSectionKey]];
    NSString *linkText = [symptoms[indexPath.row] objectForKey:kDataSourceLinkTextKey];
    NSString *urlText = [symptoms[indexPath.row] objectForKey:kDataSourceCellPictureKey];
   
//    self.isCellSelected = YES;
//    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:nil];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:linkText message:@"" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:nil];
    if (urlText.length >0) {
        [alert show];
    } else {    }
}

//- (void)tableView:(UITableView *)tableView didUnhighlightRowAtIndexPath:(NSIndexPath *)indexPath {
//    self.isCellSelected = NO;
//    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:nil];
//}
@end
