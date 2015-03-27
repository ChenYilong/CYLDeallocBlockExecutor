//
//  ColorLinkTableView.m
//  LinkTableViewDemo
//
//  Created by chenyilong on 15/3/26.
//  Copyright (c) 2015年 chenyilong. All rights reserved.
//

#import "ColorLinkTableView.h"

@implementation ColorLinkTableView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self = [self sharedInit];
    }
    return self;
}
- (id)initWithCoder: (NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self) {
        self = [self sharedInit];
    }
    return self;
}

- (id)sharedInit {
    self.separatorStyle = UITableViewCellSeparatorStyleNone;
    return self;
    
}
-(id)initWithFrame:(CGRect)frame attributedTitle:(NSAttributedString *)attributedTitle {
    self = [super initWithFrame:frame];
    if (self) {
        [self sharedInit];
    }
    return self;
}
-(void)layoutSubviews {
    [super layoutSubviews];
}
@end
