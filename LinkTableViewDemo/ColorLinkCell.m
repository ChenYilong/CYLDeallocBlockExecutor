//
//  ColorLinkCell.m
//  LinkTableViewDemo
//
//  Created by chenyilong on 15/3/26.
//  Copyright (c) 2015年 chenyilong. All rights reserved.
//

#import "ColorLinkCell.h"

@implementation ColorLinkCell

+ (instancetype)cellWithTableView:(UITableView *)tableView
{
    static NSString *CellIdentifier = @"Cell";
    ColorLinkCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[ColorLinkCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    return cell;
}
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // 1.添加原创微博的子控件
        [self setupAllSubviews];
        // 4.设置背景
        [self setupBg];
    }
    return self;
}

/**
 *  设置背景
 */
- (void)setupBg
{
    self.backgroundColor = [UIColor clearColor];
}

-(void)setupAllSubviews {
    self.bgButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.bgButton.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    self.bgButton.userInteractionEnabled = NO;
    self.bgButton.contentVerticalAlignment = NSTextAlignmentLeft;
    self.bgButton.titleEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
    [self addSubview:self.bgButton];
}


@end
