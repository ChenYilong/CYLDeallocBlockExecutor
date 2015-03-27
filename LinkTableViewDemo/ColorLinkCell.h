//
//  ColorLinkCell.h
//  LinkTableViewDemo
//
//  Created by chenyilong on 15/3/26.
//  Copyright (c) 2015年 chenyilong. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ColorLinkCell : UITableViewCell
/**
*  创建一个cell
*
*  @param tableView 从哪个tableView的缓存池中取出cell
*/
+ (instancetype)cellWithTableView:(UITableView *)tableView;
@property (nonatomic, strong) UIButton *bgButton;
@end
