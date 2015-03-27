//
//  NSString+Size.m
//  LinkTableViewDemo
//
//  Created by chenyilong on 15/3/27.
//  Copyright (c) 2015年 chenyilong. All rights reserved.
//

#import "NSString+Size.h"
#import <UIKit/UIKit.h>
@implementation NSString (Size)
-(float)getWidthWithSystemFontSize:(float)fontSize {
    CGSize size = [self sizeWithAttributes:
                   @{NSFontAttributeName:
                         [UIFont systemFontOfSize:fontSize]}];
    return ceilf(size.width);
}

+(float)getHeighthWithSystemFontSize:(float)fontSize {
    CGSize size = [@"随便写一个不就行了？" sizeWithAttributes:
                   @{NSFontAttributeName:
                         [UIFont systemFontOfSize:fontSize]}];
    return ceilf(size.height);
}
@end
