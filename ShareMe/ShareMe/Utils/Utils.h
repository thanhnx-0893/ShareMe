//
//  Utils.h
//  ShareMe
//
//  Created by Nguyen Xuan Thanh on 8/26/16.
//  Copyright © 2016 Framgia. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface Utils : NSObject

+ (CGFloat)screenWidth;
+ (UIImage *)getAvatar:(NSString *)imageString gender:(BOOL)gender;
+ (UIImage *)resize:(UIImage *)image scaledToSize:(CGSize)newSize;
+ (NSString *)stringfromNumber:(NSUInteger)number;
+ (NSString *)timeDiffFromDate:(NSString *)dateString;

@end
