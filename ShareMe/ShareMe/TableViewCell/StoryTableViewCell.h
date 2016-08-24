//
//  StoryTableViewCell.h
//  ShareMe
//
//  Created by Nguyen Xuan Thanh on 8/24/16.
//  Copyright © 2016 Framgia. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Story;

@interface StoryTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIImageView *imvAvatar;
@property (weak, nonatomic) IBOutlet UILabel *lblFullName;
@property (weak, nonatomic) IBOutlet UILabel *lblUserName;
@property (weak, nonatomic) IBOutlet UILabel *lblCreatedTime;
@property (weak, nonatomic) IBOutlet UITextView *txvContent;
@property (weak, nonatomic) IBOutlet UIImageView *imvContent;
@property (weak, nonatomic) IBOutlet UILabel *lblNumberOfLikes;
@property (weak, nonatomic) IBOutlet UILabel *lblNumberOfComments;

- (void)setStory:(Story *)story;

@end
