//
//  RequestsTableViewController.m
//  ShareMe
//
//  Created by Nguyen Xuan Thanh on 8/24/16.
//  Copyright © 2016 Framgia. All rights reserved.
//

#import "RequestViewController.h"
#import "MainTabBarViewController.h"
#import "ReceivedRequestTableViewCell.h"
#import "SentRequestTableViewCell.h"
#import "ClientSocketController.h"
#import "UIViewController+RequestHandler.h"
#import "UIViewController+ResponseHandler.h"
#import "UIViewConstant.h"
#import "User.h"

typedef NS_ENUM(NSInteger, UserRequestActions) {
    UserSendRequestToUserAction,
    UserDeclineRequestToUserAction,
    UserCancelRequestToUserAction,
    UserAddFriendToUserAction,
    AddAcceptRequestToClientsAction,
    AddDeclineRequestToClientsAction,
    AddCancelRequestToClientsAction,
    AddSendRequestToClientsAction,
    AddUnfriendToClientsAction
};

typedef NS_ENUM(NSInteger, UserResponseActions) {
    UserAcceptRequestAction,
    UserDeclineRequestAction,
    UserCancelRequestAction,
};

typedef NS_ENUM(NSInteger, RequestSections) {
    ReceivedRequestSection,
    SentRequestSection
};

static NSString *const kReceivedRequestReuseIdentifier = @"ReceivedRequestCell";
static NSString *const kSentRequestReuseIdentifier = @"SentRequestCell";
static NSString *const kRequestFormat = @"%ld-%ld";
static NSString *const kDefaultMessageTitle = @"Warning";
static NSString *const kAcceptRequestErrorMessage = @"Something went wrong! Can not accept friend request!";
static NSString *const kDeclineRequestErrorMessage = @"Something went wrong! Can not decline friend request!";
static NSString *const kCancelRequestErrorMessage = @"Something went wrong! Can not cancel friend request!";
static NSString *const kNoRequestsMessage = @"No new requests.";

@interface RequestViewController () {
    User *_currentUser;
    NSArray<User *> *_receivedRequests;
    NSArray<User *> *_sentRequests;
    NSArray<NSString *> *_requestActions;
    NSArray<NSString *> *_responseActions;
}

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *scRequestType;
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;

@end

@implementation RequestViewController

#pragma mark - UIView Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    _requestActions = @[
        kUserSendRequestToUserAction,
        kUserDeclineRequestToUserAction,
        kUserCancelRequestToUserAction,
        kUserAddFriendToUserAction,
        kAddAcceptRequestToClientsAction,
        kAddDeclineRequestToClientsAction,
        kAddCancelRequestToClientsAction,
        kAddSendRequestToClientsAction,
        kAddUnfriendToClientsAction
    ];
    _responseActions = @[
        kUserAcceptRequestAction,
        kUserDeclineRequestAction,
        kUserCancelRequestAction
    ];
    [self registerRequestHandler];
    _currentUser = ((MainTabBarViewController *)self.navigationController.tabBarController).loggedInUser;
    _receivedRequests = _currentUser.receivedRequests;
    _sentRequests = _currentUser.sentRequests;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.allowsSelection = NO;
    UIFont *font = [UIFont fontWithName:kDefaultFontName size:15];
    [self.scRequestType setTitleTextAttributes:@{NSFontAttributeName: font} forState:UIControlStateNormal];
}

- (void)viewWillAppear:(BOOL)animated {
    self.scRequestType.selectedSegmentIndex = 0;
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.navigationController && ![self.navigationController.viewControllers containsObject:self]) {
        [self resignRequestHandler];
    }
}

#pragma mark - UITableViewDatasource, UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numberOfRowsInSection = 0;
    switch (self.scRequestType.selectedSegmentIndex) {
        case ReceivedRequestSection:
            numberOfRowsInSection = _receivedRequests.count;
            break;
        case SentRequestSection:
            numberOfRowsInSection = _sentRequests.count;
            break;
    }
    if (numberOfRowsInSection == 0) {
        self.lblTitle.text = kNoRequestsMessage;
        self.lblTitle.textAlignment = NSTextAlignmentCenter;
    } else {
        self.lblTitle.text = [NSString stringWithFormat:@"%@:", [self.scRequestType
            titleForSegmentAtIndex:self.scRequestType.selectedSegmentIndex]];
        self.lblTitle.textAlignment = NSTextAlignmentLeft;
    }
    return numberOfRowsInSection;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (self.scRequestType.selectedSegmentIndex) {
        case ReceivedRequestSection: {
            ReceivedRequestTableViewCell *cell = [tableView
                dequeueReusableCellWithIdentifier:kReceivedRequestReuseIdentifier forIndexPath:indexPath];
            if (cell) {
                [cell setUser:_receivedRequests[indexPath.row]];
                cell.btnAccept.tag = indexPath.row;
                cell.btnDecline.tag = indexPath.row;
                return cell;
            }
        }
        case SentRequestSection: {
            SentRequestTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kSentRequestReuseIdentifier
                forIndexPath:indexPath];
            if (cell) {
                [cell setUser:_sentRequests[indexPath.row]];
                cell.btnCancel.tag = indexPath.row;
                return cell;
            }
        }
    }
    return [UITableViewCell new];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

#pragma mark - IBAction

- (IBAction)requestTypeValueChanged:(UISegmentedControl *)sender {
    [self.tableView reloadData];
}

- (IBAction)btnAcceptTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    NSString *data = [NSString stringWithFormat:kRequestFormat, _currentUser.userId.integerValue,
        _receivedRequests[index].userId.integerValue];
    [ClientSocketController sendData:data messageType:kSendingRequestSignal actionName:kUserAcceptRequestAction
        sender:self];
}

- (IBAction)btnDeclineTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    NSString *data = [NSString stringWithFormat:kRequestFormat, _currentUser.userId.integerValue,
        _receivedRequests[index].userId.integerValue];
    [ClientSocketController sendData:data messageType:kSendingRequestSignal actionName:kUserDeclineRequestAction
        sender:self];
}

- (IBAction)btnCancelTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    NSString *data = [NSString stringWithFormat:kRequestFormat, _currentUser.userId.integerValue,
        _sentRequests[index].userId.integerValue];
    [ClientSocketController sendData:data messageType:kSendingRequestSignal actionName:kUserCancelRequestAction
        sender:self];
}

#pragma mark - Request Handler

- (void)registerRequestHandler {
    for (NSString *action in _requestActions) {
        [ClientSocketController registerRequestHandler:action receiver:self];
    }
}

- (void)resignRequestHandler {
    for (NSString *action in _requestActions) {
        [ClientSocketController resignRequestHandler:action receiver:self];
    }
}

- (void)handleRequest:(NSString *)actionName message:(NSString *)message {
    NSError *error;
    User *user = [[User alloc] initWithString:message error:&error];
    // TODO: Handle error
    NSInteger index = [_requestActions indexOfObject:actionName];
    switch (index) {
        case UserSendRequestToUserAction:
            [self addUserIfNotExist:_currentUser.receivedRequests user:user];
            break;
        case UserCancelRequestToUserAction:
            [self removeUser:_currentUser.receivedRequests user:user];
            break;
        case UserAddFriendToUserAction:
            [self addUserIfNotExist:_currentUser.friends user:user];
            [self removeUser:_currentUser.sentRequests user:user];
            break;
        case UserDeclineRequestToUserAction:
            [self removeUser:_currentUser.sentRequests user:user];
            break;
        case AddAcceptRequestToClientsAction:
            [self removeUser:_currentUser.receivedRequests user:user];
            [self addUserIfNotExist:_currentUser.friends user:user];
            break;
        case AddDeclineRequestToClientsAction:
            [self removeUser:_currentUser.receivedRequests user:user];
            break;
        case AddCancelRequestToClientsAction:
            [self removeUser:_currentUser.sentRequests user:user];
            break;
        case AddSendRequestToClientsAction:
            [self addUserIfNotExist:_currentUser.sentRequests user:user];
            break;
        case AddUnfriendToClientsAction:
            [self removeUser:_currentUser.friends user:user];
            break;
    }
    if (self.isViewLoaded && self.view.window) {
        [self.tableView reloadData];
    }
}

#pragma mark - Process Entity

- (void)addUserIfNotExist:(NSMutableArray *)array user:(User *)user {
    BOOL isExist = NO;
    for (User *temp in array) {
        if (temp.userId == user.userId) {
            isExist = YES;
            break;
        }
    }
    if (!isExist) {
        [array addObject:user];
    }
}

- (void)removeUser:(NSMutableArray *)array user:(User *)user {
    for (User *temp in array) {
        if (temp.userId == user.userId) {
            [array removeObject:temp];
            break;
        }
    }
}

#pragma mark - Response Handler

- (void)handleResponse:(NSString *)actionName message:(NSString *)message {
    NSInteger index = [_responseActions indexOfObject:actionName];
    switch (index) {
        case UserAcceptRequestAction:
            if ([message isEqualToString:kFailureMessage]) {
                [self showMessage:kAcceptRequestErrorMessage title:kDefaultMessageTitle complete:nil];
            } else {
                NSError *error;
                User *user = [[User alloc] initWithString:message error:&error];
                // TODO: Handle error
                [self removeUser:_currentUser.receivedRequests user:user];
                [self addUserIfNotExist:_currentUser.friends user:user];
                [self.tableView reloadData];
            }
            break;
        case UserDeclineRequestAction:
            if ([message isEqualToString:kFailureMessage]) {
                [self showMessage:kDeclineRequestErrorMessage title:kDefaultMessageTitle complete:nil];
            } else {
                NSError *error;
                User *user = [[User alloc] initWithString:message error:&error];
                // TODO: Handle error
                [self removeUser:_currentUser.receivedRequests user:user];
                [self.tableView reloadData];
            }
            break;
        case UserCancelRequestAction:
            if ([message isEqualToString:kFailureMessage]) {
                [self showMessage:kCancelRequestErrorMessage title:kDefaultMessageTitle complete:nil];
            } else {
                NSError *error;
                User *user = [[User alloc] initWithString:message error:&error];
                // TODO: Handle error
                [self removeUser:_currentUser.sentRequests user:user];
                [self.tableView reloadData];
            }
            break;
    }
}

@end
