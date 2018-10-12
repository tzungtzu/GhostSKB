//
//  GHInputSourceManager.m
//  GhostSKB
//
//  Created by dmx on 2018/5/14.
//  Copyright © 2018 丁明信. All rights reserved.
//

#import "GHInputSourceManager.h"
#import "GHInputSource.h"
#import "GHKeybindingManager.h"
#import <Carbon/Carbon.h>

static GHInputSourceManager *sharedManager;

@interface GHInputSourceManager ()

@property (strong) NSMutableDictionary *inputSources;
@property TISInputSourceRef asciiInputSource;
- (void)updateInputSourceList;
@end

@implementation GHInputSourceManager

- (GHInputSourceManager *)init
{
    self = [super init];
    if (self) {
        self.inputSources = [[NSMutableDictionary alloc] initWithCapacity:2];
        [self updateInputSourceList];
    }
    return self;
}

+ (GHInputSourceManager *)getInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[GHInputSourceManager alloc] init];
    });
    return sharedManager;
}

- (void)updateInputSourceList {
    if(self.inputSources != NULL) {
        [self.inputSources removeAllObjects];
    }
    
    NSDictionary *property=[NSDictionary dictionaryWithObject:(NSString*)kTISCategoryKeyboardInputSource
                                                       forKey:(NSString*)kTISPropertyInputSourceCategory];
    CFArrayRef availableInputs = TISCreateInputSourceList((__bridge CFDictionaryRef)property, FALSE);
    NSUInteger count = CFArrayGetCount(availableInputs);
    for (int i = 0; i < count; i++) {
        TISInputSourceRef inputSource = (TISInputSourceRef)CFArrayGetValueAtIndex(availableInputs, i);
        GHInputSource *ghInputSource = [[GHInputSource alloc] initWithInputSource:inputSource];
        [self.inputSources setObject:ghInputSource forKey:ghInputSource.inputSourceId];
    }
    self.asciiInputSource = TISCopyCurrentASCIICapableKeyboardLayoutInputSource();
}

- (BOOL)selectNonCJKVInputSource {
    TISSelectInputSource(self.asciiInputSource);
    return TRUE;
}

- (BOOL)selectInputSource:(NSString *)inputSourceId {
    TISInputSourceRef currentInputSource = TISCopyCurrentKeyboardInputSource();
    NSString *currentInputId = (__bridge  NSString *)TISGetInputSourceProperty(currentInputSource, kTISPropertyInputSourceID);
    if ([currentInputId isEqualToString:inputSourceId]) {
        return TRUE;
    }
    CFRelease(currentInputSource);
    
    GHInputSource *ghInputSource = [self.inputSources objectForKey:inputSourceId];
    if(ghInputSource == NULL) {
        return FALSE;
    }

    if ([ghInputSource isCJKV]) {
        [ghInputSource select];
        [NSThread sleepForTimeInterval:0.15];
        if([self canExecuteSwitchScript]) {
            [self selectNonCJKVInputSource];
            [self selectPreviousInputSource];
        }
    }
    else {
        [ghInputSource select];
    }
    return TRUE;
}

- (BOOL)hasInputSourceEnabled:(NSString *)inputSourceId {
    GHInputSource *ghInputSource = [self.inputSources objectForKey:inputSourceId];
    return ghInputSource != NULL;
}

- (void)selectPreviousInputSource {
    [self executeSwitchScript];
}

- (void)executeSwitchScript {
    ProcessSerialNumber psn = {0, kCurrentProcess};
    NSAppleEventDescriptor *target = [NSAppleEventDescriptor descriptorWithDescriptorType:typeProcessSerialNumber bytes:&psn length:sizeof(ProcessSerialNumber)];
    
    // function
    NSAppleEventDescriptor *function = [NSAppleEventDescriptor descriptorWithString:@"switch"];
    
    // event
    NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite eventID:kASSubroutineEvent targetDescriptor:target returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
    [event setParamDescriptor:function forKeyword:keyASSubroutineName];
    
    NSError *error;
    NSURL *scriptURL = [self switchScriptURL];
    NSUserAppleScriptTask *task = [[NSUserAppleScriptTask alloc] initWithURL:scriptURL error:&error];
    if(error) {
        NSLog(@"task init error %@", error);
    }
    
    [task executeWithAppleEvent:event completionHandler:^(NSAppleEventDescriptor * result, NSError * error) {
        if(error) {
            NSLog(@"execute error %@", error);
        }
    }];
}

- (NSURL *)switchScriptURL {
    NSError *error;
    NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationScriptsDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
    NSURL *scriptURL = [directoryURL URLByAppendingPathComponent:@"switch.scpt"];
    return scriptURL;
}

- (BOOL)canExecuteSwitchScript {
    NSURL *url = [self switchScriptURL];
    return [[NSFileManager defaultManager] fileExistsAtPath:[url path]];
}


@end
