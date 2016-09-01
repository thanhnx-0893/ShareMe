//
//  NSDate+TimeDiff.h
//  ShareMe
//
//  Created by Nguyen Xuan Thanh on 9/1/16.
//  Copyright © 2016 Framgia. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (TimeDiff)

- (NSDateComponents *)timeDiffFromDate:(NSDate *)date unit:(NSCalendarUnit)unit;

@end
