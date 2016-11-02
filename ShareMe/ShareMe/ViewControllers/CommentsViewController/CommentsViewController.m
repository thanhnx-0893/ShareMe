//
//  CommentsViewController.m
//  ShareMe
//
//  Created by Nguyen Xuan Thanh on 9/12/16.
//  Copyright © 2016 Framgia. All rights reserved.
//

#import "CommentsViewController.h"
#import "MainTabBarViewController.h"
#import "NewsFeedViewController.h"
#import "ClientSocketController.h"
#import "CommentTableViewCell.h"
#import "WhoLikeThisViewController.h"
#import "TimelineViewController.h"
#import "UITableView+ScrollHelpers.h"
#import "FDateFormatter.h"
#import "Utils.h"
#import "Comment.h"
#import "User.h"
#import "Story.h"

typedef NS_ENUM(NSInteger, UserResponseActions) {
    UserGetTopCommentsAction,
    UserCreateNewCommentAction,
    UserLikeStoryAction
};

typedef NS_ENUM(NSInteger, UserRequestActions) {
    AddNewCommentToUserAction,
    UpdateLikedUsersAction
};

@interface CommentsViewController () {
    Comment *_comment;
    NSInteger _startIndex;
    NSArray<NSString *> *_responseActions;
    NSArray<NSString *> *_requestActions;
    NSMutableArray<Comment *> *_topComments;
    User *_currentUser;
    NSDateFormatter *_dateFormatter;
    UIRefreshControl *_topRefreshControl;
}

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UITextView *txvAddComment;
@property (weak, nonatomic) IBOutlet UILabel *lblPlaceHolder;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *addCommentViewBottomConstraint;
@property (weak, nonatomic) IBOutlet UIButton *btnLike;
@property (weak, nonatomic) IBOutlet UIButton *btnWhoLikeThis;

@end

@implementation CommentsViewController

#pragma mark - UIView Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    CGRect frame = self.navigationItem.titleView.frame;
    frame.size.width = [UIViewConstant screenWidth];
    self.navigationItem.titleView.frame = frame;
    [self.txvAddComment becomeFirstResponder];
    _topComments = [NSMutableArray array];
    _responseActions = @[
        kUserGetTopCommentsAction,
        kUserCreateNewCommentAction,
        kUserLikeStoryAction
    ];
    _requestActions = @[
        kAddNewCommentToUserAction,
        kUpdateLikedUsersAction
    ];
    [self registerRequestHandler];
    _currentUser = ((MainTabBarViewController *)self.navigationController.tabBarController).loggedInUser;
    _dateFormatter = [FDateFormatter sharedDateFormatter];
    [self updateLikedUsers];
    [self loadComments];
    _topRefreshControl = [[UIRefreshControl alloc] init];
    [_topRefreshControl addTarget:self action:@selector(loadComments) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:_topRefreshControl];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:)
        name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:)
        name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.navigationController && ![self.navigationController.viewControllers containsObject:self]) {
        [self resignRequestHandler];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadComments {
    _startIndex = _topComments.count;
    [[ClientSocketController sharedController] sendData:[NSString stringWithFormat:kGetTopCommentsMessageFormat,
        self.story.storyId.integerValue, _startIndex, kNumberOfComments] messageType:kSendingRequestSignal
        actionName:kUserGetTopCommentsAction sender:self];
}

- (void)updateLikedUsers {
    UIImage *likedImage = [UIImage imageNamed:kLikedImage];
    UIImage *unlikedImage = [UIImage imageNamed:kUnlikedImage];
    [self.btnWhoLikeThis setTitle:@"" forState:UIControlStateNormal];
    switch (self.story.numberOfLikedUsers.integerValue) {
        case 0: {
            [self.btnLike setImage:unlikedImage forState:UIControlStateNormal];
            [self.btnWhoLikeThis setTitle:kEmptyLikedUsersLabelText forState:UIControlStateNormal];
            break;
        }
        case 1: {
            if (self.story.likedUsers.count) {
                [self.btnWhoLikeThis setTitle:kSelfLikeLabelText forState:UIControlStateNormal];
                [self.btnLike setImage:likedImage forState:UIControlStateNormal];
            } else {
                [self.btnWhoLikeThis setTitle:kOneLikeLabelText forState:UIControlStateNormal];
                [self.btnLike setImage:unlikedImage forState:UIControlStateNormal];
            }
            break;
        }
        case 2 ... NSIntegerMax: {
            if (self.story.likedUsers.count) {
                [self.btnWhoLikeThis setTitle:[NSString stringWithFormat:kSelfLikeWithOthersLabelText,
                    self.story.numberOfLikedUsers.integerValue - 1] forState:UIControlStateNormal];
                [self.btnLike setImage:likedImage forState:UIControlStateNormal];
            } else {
                [self.btnWhoLikeThis setTitle:[NSString stringWithFormat:kManyLikeLabelText,
                    self.story.numberOfLikedUsers.integerValue] forState:UIControlStateNormal];
                [self.btnLike setImage:unlikedImage forState:UIControlStateNormal];
            }
            break;
        }
    }
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    self.lblPlaceHolder.hidden = [self.txvAddComment hasText];
}

#pragma mark - UITableViewDatasource, UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!_topComments.count) {
        return 1;
    }
    return _topComments.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!_topComments.count) {
        return [Utils emptyTableCell:kEmptyCommentsTableViewMessage];
    }
    CommentTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCommentReuseIdentifier
        forIndexPath:indexPath];
    if (!cell) {
        return [UITableViewCell new];
    }
    [cell setComment:_topComments[indexPath.row]];
    [self setTapGestureRecognizer:@[cell.imvAvatar, cell.lblFullName]
        userId:_topComments[indexPath.row].creator.userId.integerValue];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!_topComments.count) {
        return tableView.frame.size.height;
    }
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (void)reloadDataWithAnimated:(BOOL)animated {
    [self.tableView reloadData];
    [self.tableView scrollToBottom:animated];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.txvAddComment resignFirstResponder];
}

#pragma mark - Packing entity

- (void)getComment {
    _comment = [[Comment alloc] init];
    User *creator = [[User alloc] init];
    creator.userId = _currentUser.userId;
    _comment.creator = creator;
    _comment.content = self.txvAddComment.text;
    _dateFormatter.dateFormat = kDefaultDateTimeFormat;
    _comment.createdTime = [_dateFormatter stringFromDate:[NSDate date]];
    Story *story = [[Story alloc] init];
    story.storyId = @(self.story.storyId.integerValue);
    _comment.story = story;
}

#pragma mark - IBAction

- (IBAction)btnBackTapped:(UIButton *)sender {
    if ([self.txvAddComment hasText]) {
        [self showConfirmDialog:kConfirmDiscardComment title:kConfirmMessageTitle handler:^(UIAlertAction *action) {
            [self dismissKeyboard];
            [self.navigationController popViewControllerAnimated:YES];
        }];
    } else {
        [self dismissKeyboard];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (IBAction)btnPostTapped:(UIButton *)sender {
    if ([self.txvAddComment hasText]) {
        [self dismissKeyboard];
        [self getComment];
        [[ClientSocketController sharedController] sendData:[_comment toJSONString] messageType:kSendingRequestSignal
            actionName:kUserCreateNewCommentAction sender:self];
    }
}

- (IBAction)btnLikeTapped:(UIButton *)sender {
    [[ClientSocketController sharedController] sendData:[NSString stringWithFormat:kLikeRequestFormat,
        self.story.storyId.integerValue, _currentUser.userId.integerValue] messageType:kSendingRequestSignal
        actionName:kUserLikeStoryAction sender:self];
}

- (IBAction)btnWhoLikeThisTapped:(UIButton *)sender {
    if (self.story.numberOfLikedUsers.integerValue) {
        [self dismissKeyboard];
        [self performSegueWithIdentifier:kGoToWhoLikeThisSegueIdentifier sender:self];
    }
}

#pragma mark - Show / hide keyboard

- (void)keyboardWillShow:(NSNotification *)notification {
    CGSize keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    NSTimeInterval duration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey]
        doubleValue];
    CGFloat offset = keyboardSize.height;
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0f, 0.0f, offset, 0.0f);
    [UIView animateWithDuration:duration animations:^{
        self.tableView.contentInset = contentInsets;
        self.tableView.scrollIndicatorInsets = contentInsets;
        self.addCommentViewBottomConstraint.constant += offset;
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSTimeInterval duration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey]
        doubleValue];
    [UIView animateWithDuration:duration animations:^{
        self.tableView.contentInset = UIEdgeInsetsZero;
        self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
        self.addCommentViewBottomConstraint.constant = 0.0f;
    }];
}

#pragma mark - Response Handler

- (void)handleResponse:(NSString *)actionName message:(NSString *)message {
    NSInteger index = [_responseActions indexOfObject:actionName];
    switch (index) {
        case UserGetTopCommentsAction: {
            if (![message isEqualToString:kFailureMessage]) {
                NSError *error;
                NSMutableArray *array = [Comment arrayOfModelsFromString:message error:&error];
                if (error) {
                    return;
                }
                array = [[[array reverseObjectEnumerator] allObjects] mutableCopy];
                [array addObjectsFromArray:_topComments];
                [_topComments removeAllObjects];
                [_topComments addObjectsFromArray:array];
                _startIndex += kNumberOfComments;;
                [self reloadDataWithAnimated:NO];
            }
            [_topRefreshControl endRefreshing];
            break;
        }
        case UserCreateNewCommentAction: {
            if ([message isEqualToString:kFailureMessage]) {
                [self showMessage:kAddNewCommentErrorMessage title:kDefaultMessageTitle complete:nil];
            } else {
                _comment.commentId = @(message.integerValue);
                _comment.creator = _currentUser;
                [_topComments addObject:_comment];
                [self.txvAddComment setText:@""];
                self.lblPlaceHolder.hidden = NO;
                [self reloadDataWithAnimated:YES];
                NSUInteger index = [self.navigationController.viewControllers indexOfObject:self] - 1;
                if ([self.navigationController.viewControllers[index] isKindOfClass:[NewsFeedViewController
                    class]]) {
                    NewsFeedViewController *newsFeedViewController = self.navigationController.viewControllers[index];
                    [newsFeedViewController addCommentToStory:_comment];
                } else if ([self.navigationController.viewControllers[index] isKindOfClass:[TimelineViewController
                    class]]) {
                    TimelineViewController *timelineViewController = self.navigationController.viewControllers[index];
                    [timelineViewController addCommentToStory:_comment];
                }
            }
            break;
        }
        case UserLikeStoryAction: {
            if (![message isEqualToString:kFailureMessage]) {
                NSArray *array = [message componentsSeparatedByString:@"-"];
                if ([array containsObject:@""]) {
                    return;
                }
                NSString *likeMessage = array[0];
                NSInteger storyId = [array[1] integerValue];
                NSInteger numberOfLikedUsers = [array[2] integerValue];
                [self updateLikeStory:likeMessage userId:_currentUser.userId.integerValue storyId:storyId
                    numberOfLikedUsers:numberOfLikedUsers];
                [self updateLikedUsers];
            }
            break;
        }
    }
}

- (void)updateLikeStory:(NSString *)likeMessage userId:(NSInteger)userId storyId:(NSInteger)storyId
    numberOfLikedUsers:(NSInteger)numberOfLikedUsers {
    if ([likeMessage isEqualToString:kLikedMessageAction]) {
        if (self.story.storyId.integerValue == storyId) {
            self.story.numberOfLikedUsers = @(numberOfLikedUsers);
            if (userId == _currentUser.userId.integerValue && !self.story.likedUsers) {
                self.story.likedUsers = (NSMutableArray<User, Optional> *)[NSMutableArray arrayWithObject:_currentUser];
            } else if (userId == _currentUser.userId.integerValue && self.story.likedUsers) {
                [self.story.likedUsers addObject:_currentUser];
            }
        }
    } else if ([likeMessage isEqualToString:kUnlikedMessageAction]) {
        if (self.story.storyId.integerValue == storyId) {
            self.story.numberOfLikedUsers = @(numberOfLikedUsers);
            if (userId == _currentUser.userId.integerValue) {
                [self.story.likedUsers removeAllObjects];
            }
        }
    }
}

#pragma mark - Request Handler

- (void)registerRequestHandler {
    for (NSString *action in _requestActions) {
        [[ClientSocketController sharedController] registerRequestHandler:action receiver:self];
    }
}

- (void)resignRequestHandler {
    for (NSString *action in _requestActions) {
        [[ClientSocketController sharedController] resignRequestHandler:action receiver:self];
    }
}

- (void)handleRequest:(NSString *)actionName message:(NSString *)message {
    NSInteger index = [_requestActions indexOfObject:actionName];
    switch (index) {
        case AddNewCommentToUserAction: {
            NSError *error;
            Comment *comment = [[Comment alloc] initWithString:message error:&error];
            if (error) {
                return;
            }
            if (comment) {
                [_topComments addObject:comment];
                [self reloadDataWithAnimated:YES];
            }
            break;
        }
        case UpdateLikedUsersAction: {
            [self updateLikedUsers];
            break;
        }
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    [super prepareForSegue:segue sender:sender];
    if ([segue.identifier isEqualToString:kGoToWhoLikeThisSegueIdentifier]) {
        WhoLikeThisViewController *whoLikeThisViewController = [segue destinationViewController];
        whoLikeThisViewController.storyId = self.story.storyId.integerValue;
    }
}

@end
