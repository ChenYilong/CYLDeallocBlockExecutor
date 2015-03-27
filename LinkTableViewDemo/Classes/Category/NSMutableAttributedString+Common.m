//
//  NSMutableAttributedString+YPGeneral.m
//  PiFuKeYiSheng
//
//  Created by chenyilong on 14-6-12.
//  Copyright (c) 2014年 chenyilong. All rights reserved.
//

#import "NSMutableAttributedString+Common.h"

@implementation NSMutableAttributedString (Common)
- (void)addFont:(UIFont *)font range:(NSRange)range
{
    [self addAttribute:NSFontAttributeName value:font range:range];
}

- (void)addColor:(UIColor *)color range:(NSRange)range
{
    [self addAttribute:NSForegroundColorAttributeName value:color range:range];
}

- (void)addLineSpace:(float)space range:(NSRange)range
{
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    [style setLineSpacing:space];
    [self addAttribute:NSParagraphStyleAttributeName
                 value:style
                 range:range];
}

- (void)addDeleteLineWithRange:(NSRange)range
{
    [self addAttribute:NSStrikethroughStyleAttributeName
                 value:@(NSUnderlineStyleSingle)
                 range:range];
}

- (void)addUnderLineWithRange:(NSRange)range
{
    [self addAttribute:NSUnderlineStyleAttributeName
                 value:@(NSUnderlineStyleSingle)
                 range:range];
}

- (NSMutableAttributedString *)convertToLinkStringWithString:(NSString *)string color:(UIColor *)color font:(UIFont *)font {
    NSRange range = NSMakeRange(0, [string length]);
     NSMutableAttributedString *mutableAttributedString = [[NSMutableAttributedString alloc] initWithString:string];
    [mutableAttributedString addColor:color range:range];
    [mutableAttributedString addFont:font range:range];
    [mutableAttributedString addUnderLineWithRange:range];
    return mutableAttributedString;
}
@end
