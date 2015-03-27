//
//  NSMutableAttributedString+YPGeneral.h
//  PiFuKeYiSheng
//
//  Created by chenyilong on 14-6-12.
//  Copyright (c) 2014年 chenyilong. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface NSMutableAttributedString (Common)
- (void)addFont:(UIFont *)font range:(NSRange)range;
- (void)addColor:(UIColor *)color range:(NSRange)range;
- (void)addLineSpace:(float)space range:(NSRange)range;
- (void)addDeleteLineWithRange:(NSRange)range;
- (void)addUnderLineWithRange:(NSRange)range;
- (NSMutableAttributedString *)convertToLinkStringWithString:(NSString *)string color:(UIColor *)color font:(UIFont *)font;
@end
