//
//  NewsFeedTableViewController.m
//  ShareMe
//
//  Created by Nguyen Xuan Thanh on 8/24/16.
//  Copyright © 2016 Framgia. All rights reserved.
//

#import "NewsFeedViewController.h"
#import "ClientSocketController.h"
#import "StoryTableViewCell.h"
#import "UIViewController+ResponseHandler.h"
#import "MainTabBarViewController.h"
#import "SearchFriendViewController.h"
#import "Utils.h"
#import "Story.h"
#import "User.h"

typedef NS_ENUM(NSInteger, UserResponseActions) {
    UserSearchFriendAction,
    UserGetTopStoriesAction
};

static NSString *const kDefaultMessageTitle = @"Warning";
static NSString *const kStoryReuseIdentifier = @"StoryCell";
static NSString *const kEmptySearchMessage = @"Please enter friend's name or email to search!";
static NSString *const kEmptySearchResultMessage = @"Could not find anything for \"%@\"!";
static NSString *const kGoToSearchFriendSegueIdentifier = @"goToSearchFriend";
static NSString *const kGoToNewStorySegueIdentifier = @"goToNewStory";
static NSString *const kRequestFormat = @"%ld-%ld";
static NSInteger const kNumberOfStories = 10;

@interface NewsFeedViewController () {
    User *_currentUser;
    NSArray<User *> *_searchResult;
    NSMutableArray<Story *> *_topStories;
    NSArray<NSString *> *_responseActions;
    NSInteger _startIndex;
    NSMutableDictionary<NSNumber *, NSNumber *> *_imageIndexes;
}

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (weak, nonatomic) IBOutlet UITextField *txtSearch;
@property (strong, nonatomic) IBOutlet UISwipeGestureRecognizer *swipeLeftGestureRecognizer;
@property (strong, nonatomic) IBOutlet UISwipeGestureRecognizer *swipeRightGestureRecognizer;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *searchTextFieldLeadingConstraint;

@end

@implementation NewsFeedViewController

#pragma mark - UIView Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.estimatedRowHeight = 44.0f;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.allowsSelection = NO;
    CGRect frame = self.navigationItem.titleView.frame;
    frame.size.width = [Utils screenWidth];
    self.navigationItem.titleView.frame = frame;
    _currentUser = ((MainTabBarViewController *)self.navigationController.tabBarController).loggedInUser;
    _responseActions = @[
        kUserSearchFriendAction,
        kUserGetTopStoriesAction
    ];
    _startIndex = 0;
    _topStories = [NSMutableArray array];
    _imageIndexes = [NSMutableDictionary dictionary];
    [self loadTopStories];
}

#pragma mark - IBAction

- (void)loadTopStories {
    [ClientSocketController sendData:[NSString stringWithFormat:kRequestFormat, _startIndex,
        kNumberOfStories] messageType:kSendingRequestSignal actionName:kUserGetTopStoriesAction sender:self];
}

- (IBAction)btnSearchTapped:(UIButton *)sender {
    if (self.lblTitle.alpha == 1.0f) {
        [self.searchTextFieldLeadingConstraint setConstant:-CGRectGetWidth(self.lblTitle.frame)];
        [self.navigationItem.titleView setNeedsUpdateConstraints];
        [UIView animateWithDuration:0.4 animations:^{
            self.lblTitle.alpha = 0.0f;
            [self.navigationItem.titleView layoutIfNeeded];
        }];
        [self.txtSearch becomeFirstResponder];
        return;
    }
    if ([self.txtSearch.text isEqualToString:@""]) {
        [self showMessage:kEmptySearchMessage title:kDefaultMessageTitle complete:^(UIAlertAction *action) {
            [self.txtSearch becomeFirstResponder];
        }];
        return;
    }
    [self.txtSearch resignFirstResponder];
    [ClientSocketController sendData:self.txtSearch.text messageType:kSendingRequestSignal
        actionName:kUserSearchFriendAction sender:self];
}

- (IBAction)btnReloadTapped:(UIButton *)sender {
    // TODO: Reload news feed
}

- (IBAction)btnNewStoryTapped:(id)sender {
    [self.navigationController.tabBarController.tabBar setHidden:YES];
    [self performSegueWithIdentifier:kGoToNewStorySegueIdentifier sender:self];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.txtSearch) {
        [self btnSearchTapped:nil];
        return YES;
    }
    return NO;
}

#pragma mark - 

- (IBAction)swipeLeftGestureRecognizer:(UISwipeGestureRecognizer *)sender {
    StoryTableViewCell *cell = (StoryTableViewCell *) sender.view;
    NSInteger index = cell.tag;
    NSInteger currentImageIndex = _imageIndexes[@(index)].integerValue;
    if (currentImageIndex) {
        // TODO
    }
}

- (IBAction)swipeRightGestureRecognizer:(UISwipeGestureRecognizer *)sender {
    StoryTableViewCell *cell = (StoryTableViewCell *) sender.view;
    NSInteger index = cell.tag;
    NSInteger currentImageIndex = _imageIndexes[@(index)].integerValue;
    if (currentImageIndex < _topStories[index].images.count - 1) {
        // TODO
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self dissmissKeyboard];
}

- (void)dissmissKeyboard {
    [self.txtSearch resignFirstResponder];
    [self.searchTextFieldLeadingConstraint setConstant:-10.0f];
    [self.navigationItem.titleView setNeedsUpdateConstraints];
    [UIView animateWithDuration:0.4 animations:^{
        [self.navigationItem.titleView layoutIfNeeded];
        self.lblTitle.alpha = 1.0f;
    }];
}

#pragma mark - UITableViewDatasource, UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _topStories.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    StoryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kStoryReuseIdentifier
        forIndexPath:indexPath];
    if (!cell) {
        return [UITableViewCell new];
    }
    cell.tag = indexPath.row;
    NSInteger imageIndex = 0;
    if (_topStories[indexPath.row].images.count > 1) {
        if (!_imageIndexes[@(indexPath.row)]) {
            _imageIndexes[@(indexPath.row)] = @(0);
        } else {
            imageIndex = _imageIndexes[@(indexPath.row)].integerValue;
        }
        [cell addGestureRecognizer:self.swipeLeftGestureRecognizer];
        [cell addGestureRecognizer:self.swipeRightGestureRecognizer];
    }
    [cell setStory:_topStories[indexPath.row] imageIndex:imageIndex];
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger lastSectionIndex = [tableView numberOfSections] - 1;
    NSInteger lastRowIndex = [tableView numberOfRowsInSection:lastSectionIndex] - 1;
    if (indexPath.section == lastSectionIndex && indexPath.row == lastRowIndex) {
        [self loadTopStories];
    }
}

#pragma mark - Response Handler

- (void)handleResponse:(NSString *)actionName message:(NSString *)message {
    NSInteger index = [_responseActions indexOfObject:actionName];
    switch (index) {
        case UserSearchFriendAction:
            if ([message isEqualToString:kFailureMessage]) {
                [self showMessage:[NSString stringWithFormat:kEmptySearchResultMessage, self.txtSearch.text]
                            title:kDefaultMessageTitle complete:nil];
            } else {
                NSError *error;
                _searchResult = [User arrayOfModelsFromString:message error:&error];
                // TODO: Handle error
                [self dissmissKeyboard];
                [self performSegueWithIdentifier:kGoToSearchFriendSegueIdentifier sender:self];
                self.txtSearch.text = @"";
            }
            break;
        case UserGetTopStoriesAction:
            if ([message isEqualToString:kFailureMessage]) {
                // TODO: Replace blank table view
            } else {
                NSError *error;
                [_topStories addObjectsFromArray:[Story arrayOfModelsFromString:message error:&error]];
                _startIndex += kNumberOfStories;
                // TODO: Handle error
                // TODO: Fix can't read UTF-8 story issue
                [self.tableView reloadData];
            }
            break;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:kGoToSearchFriendSegueIdentifier]) {
        SearchFriendViewController *searchFriendTableViewController = [segue destinationViewController];
        searchFriendTableViewController.users = _searchResult;
        searchFriendTableViewController.keyword = self.txtSearch.text;
    }
}

@end
