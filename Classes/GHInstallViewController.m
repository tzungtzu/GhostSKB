//
//  GHInstallViewController.m
//  GhostSKB
//
//  Created by mingxin.ding on 2018/10/9.
//  Copyright © 2018 丁明信. All rights reserved.
//

#import "GHInstallViewController.h"
#import "GHKeybindingManager.h"
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

#define SYMBOLICHOTKEYS @"com.apple.symbolichotkeys.plist"
#define SOURCE_SCRIPT_FILE @"switch_scpt"


@interface GHInstallViewController ()

@end

@implementation GHInstallViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (void)doInstallScript {
    NSError *error;
    NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationScriptsDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setDirectoryURL:directoryURL];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:NO];
    [openPanel setPrompt:@"Select Script Folder"];
    NSString *message = [NSString stringWithFormat:@"Please select the User > Library > Application Scripts > %@", [[NSBundle mainBundle] bundleIdentifier]];
    [openPanel setMessage:message];
    
    [openPanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *selectedURL = [openPanel URL];
            if ([selectedURL isEqual:directoryURL]) {
                NSURL *destinationURL = [selectedURL URLByAppendingPathComponent:@"switch.scpt"];
                NSFileManager *fileManager = [NSFileManager defaultManager];
                NSURL *sourceURL = [[NSBundle mainBundle] URLForResource:SOURCE_SCRIPT_FILE withExtension:@"txt"];
        
                NSError *error;
                BOOL success = false;
                
                if([fileManager fileExistsAtPath:[destinationURL path]]) {
                    NSString *fileName = [NSString stringWithFormat:@"%@.txt", SOURCE_SCRIPT_FILE];
                    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
                    [fileManager copyItemAtURL:sourceURL toURL:[NSURL fileURLWithPath:tmpPath] error:NULL];
                    
                    //replaceItemAtURL is a move action
                    success = [fileManager replaceItemAtURL:destinationURL withItemAtURL:[NSURL fileURLWithPath:tmpPath] backupItemName:NULL options:NSFileManagerItemReplacementUsingNewMetadataOnly resultingItemURL:NULL error:&error];
                }
                else {
                    success = [fileManager copyItemAtURL:sourceURL toURL:destinationURL error:&error];
                }
                
                
                if (success) {
                    NSAlert *alert = [NSAlert alertWithMessageText:@"Script Installed" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"The Switch script was installed succcessfully."];
                    [alert runModal];
                
                    // NOTE: This is a bit of a hack to get the Application Scripts path out of the next open or save panel that appears.
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NSNavLastRootDirectory"];
                }
                else {
                    NSLog(@"%s error = %@", __PRETTY_FUNCTION__, error);
                }
            }
        }
    }];
    
    
}

- (void)executeSwitchScript {
    ProcessSerialNumber psn = {0, kCurrentProcess};
    NSAppleEventDescriptor *target = [NSAppleEventDescriptor descriptorWithDescriptorType:typeProcessSerialNumber bytes:&psn length:sizeof(ProcessSerialNumber)];
    
    // function
    NSAppleEventDescriptor *function = [NSAppleEventDescriptor descriptorWithString:@"switch"];
    
    // event
    NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite eventID:kASSubroutineEvent targetDescriptor:target returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
    [event setParamDescriptor:function forKeyword:keyASSubroutineName];
    
    //        NSUserAppleScriptTask *task = [[NSUserAppleScriptTask alloc] initWithURL:[NSURL URLWithString:scriptFilePath] error:NULL];
    NSError *error;
    NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationScriptsDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
    NSURL *scriptURL = [directoryURL URLByAppendingPathComponent:@"switch.scpt"];
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

- (IBAction)installScript:(id)sender {
    if(true) {
        [self doInstallScript];
        return;
    }
}

- (IBAction)getSystemShortcuts:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libDir = [dirs objectAtIndex:0];
    [panel setDirectoryURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/Preferences/%@", libDir, SYMBOLICHOTKEYS]]];
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setAllowedFileTypes:@[@"plist"]];
    panel.delegate = self;
    
    NSWindow *window = self.view.window;
    [panel beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
        if(result != NSFileHandlingPanelOKButton) {
            return;
        }
        for (NSURL *url in [panel URLs]) {
            NSError *error;
            NSData *data = [NSData dataWithContentsOfURL:url];
            NSPropertyListFormat plistFormat;
            NSDictionary *dict = (NSDictionary *)[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:&plistFormat error:&error];
            if (!error) {
                //                NSLog(@"plist dict: %@", dict);
                [self getPreviousInputSourceShortCut:dict];
            }
            break;
        }
    }];
}

- (void)getPreviousInputSourceShortCut:(NSDictionary *)dict {
    NSDictionary* hotKeys = dict[@"AppleSymbolicHotKeys"];
    if (!hotKeys) {
        NSLog(@"AppleSymbolicHotKeys not exist");
        return;
    }
    NSDictionary *hotKey = hotKeys[@"60"];
    if (!hotKey) {
        NSLog(@"60 hotkey not exist");
        return;
    }
    
    NSNumber *enabled = hotKey[@"enabled"];
    if ([enabled intValue] != 1) {
        NSLog(@"hot key not enabled");
        return;
    }
    
    NSDictionary *value = hotKey[@"value"];
    NSArray *parameters = value[@"parameters"];
    if (!parameters) {
        NSLog(@"no parameters");
        return;
    }
    
    NSNumber *key = parameters[0];
    NSUInteger modifier = [parameters[1] unsignedIntegerValue];
    [[GHKeybindingManager getInstance] setSystemSelectPreviousKey:key withModifier:modifier];
//    NSLog(@"key:%ld modifier:%ld", [key intValue], modifier);
}

#pragma mark - NSOpenSavePanelDelegate

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url {
    if ([url.path containsString:SYMBOLICHOTKEYS]) {
        return YES;
    }
    else {
        return NO;
    }
}

@end
