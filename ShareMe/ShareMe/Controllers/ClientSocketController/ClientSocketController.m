//
//  MainAppController.m
//  SocialNetwork
//
//  Created by Nguyen Xuan Thanh on 8/10/16.
//  Copyright © 2016 Nguyen Xuan Thanh. All rights reserved.
//

#import "ClientSocketController.h"
#import "UIViewController+ResponseHandler.h"
#import "UIViewController+RequestHandler.h"

static NSOutputStream *kOutputStream;
static NSMutableDictionary<NSString *, UIViewController *> *kResponses;
static NSMutableDictionary<NSString *, NSMutableArray *> *kRequests;
static NSData *kRemainData;

@interface ClientSocketController () {
    CFReadStreamRef _readStream;
    CFWriteStreamRef _writeStream;
    NSInputStream *_inputStream;
    NSString *_receivedMessage;
}

@end

@implementation ClientSocketController

- (instancetype)init {
    self = [super init];
    if (self) {
        kResponses = [NSMutableDictionary dictionary];
        kRequests = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)openSocket {
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (__bridge CFStringRef) kServerHost, kServerPort,
        &_readStream, &_writeStream);
    kOutputStream = (__bridge NSOutputStream *)_writeStream;
    _inputStream = (__bridge NSInputStream *)_readStream;
    [kOutputStream setDelegate:self];
    [_inputStream setDelegate:self];
    [kOutputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [kOutputStream open];
    [_inputStream open];
}

- (void)closeSocket {
    [_inputStream close];
    [kOutputStream close];
    [_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [kOutputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [_inputStream setDelegate:nil];
    [kOutputStream setDelegate:nil];
    _inputStream = nil;
    kOutputStream = nil;
}

+ (void)sendData:(NSString *)message messageType:(NSString *)messageType actionName:(NSString *)actionName
    sender:(UIViewController *)sender {
    NSString *finalMessage = [[NSString stringWithFormat:kMessageFormat, messageType, actionName, message]
        stringByAppendingString:kEndOfStream];
    NSData *data = [finalMessage dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t *bytes = (uint8_t *) [data bytes];
    NSInteger bytesWritten = [kOutputStream write:bytes maxLength:[data length]];
    if (bytesWritten < [data length]) {
        if (bytesWritten != -1) {
            bytes += bytesWritten;
        }
        kRemainData = [NSData dataWithBytes:bytes length:strlen((char *)bytes)];
    }
    kResponses[actionName] = sender;
}

+ (void)registerRequestHandler:(NSString *)actionName receiver:(UIViewController *)receiver {
    NSMutableArray *array = [kRequests valueForKey:actionName];
    if (array) {
        if (![array containsObject:receiver]) {
            [array addObject:receiver];
        }
    } else {
        array = @[receiver].mutableCopy;
        kRequests[actionName] = array;
    }
}

#pragma mark - Process message from server

- (void)readMessage {
    _receivedMessage = @"";
    uint8_t buffer[1024];
    NSString *temp;
    do {
        NSInteger value = [_inputStream read:buffer maxLength:sizeof(buffer)];
        if (value > 0) {
            temp = [[NSString alloc] initWithBytes:buffer length:value encoding:NSUTF8StringEncoding];
            if (temp) {
                _receivedMessage = [_receivedMessage stringByAppendingString:temp];
            }
        }
    } while (![_receivedMessage hasSuffix:kEndOfStream]);
}

- (void)handleMessage {
    if (_receivedMessage) {
        _receivedMessage = [_receivedMessage substringToIndex:_receivedMessage.length - kEndOfStream.length];
        NSArray *result = [_receivedMessage componentsSeparatedByString:kDelim];
        if (result.count <= 2) {
            return;
        } else {
            for (NSString *str in result) {
                if ([str isEqualToString:@""]) {
                    return;
                }
            }
        }
        if ([result[0] isEqualToString:kReceivingRequestSignal]) {
            [[kResponses objectForKey:result[1]] handleResponse:result[1] message:result[2]];
            [kResponses removeObjectForKey:result[1]];
        } else if ([result[0] isEqualToString:kSendingRequestSignal]) {
            NSArray *array = [kRequests objectForKey:result[1]];
            for (UIViewController *viewController in array) {
                [viewController handleRequest:result[1] message:result[2]];
            }
        }
    }
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    switch (streamEvent) {
        case NSStreamEventOpenCompleted:
            break;
        case NSStreamEventHasBytesAvailable:
            if (theStream == _inputStream) {
                [self readMessage];
                [self handleMessage];
            }
            break;
        case NSStreamEventHasSpaceAvailable: {
            if (kRemainData) {
                uint8_t *bytes = (uint8_t *) [kRemainData bytes];
                NSInteger bytesWritten = [kOutputStream write:bytes maxLength:[kRemainData length]];
                if (bytesWritten < [kRemainData length]) {
                    if (bytesWritten != -1) {
                        bytes += bytesWritten;
                    }
                    kRemainData = [NSData dataWithBytes:bytes length:strlen((char *)bytes)];
                } else {
                    kRemainData = nil;
                }
            }
            break;
        }
        case NSStreamEventErrorOccurred:
            // TODO
            [self closeSocket];
            break;
        case NSStreamEventEndEncountered:
            // TODO
            [theStream close];
            [theStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            break;
        default:
            break;
    }
}

@end
