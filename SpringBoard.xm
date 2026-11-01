//
//  SpringBoard.xm
//  FLEXing
//
//  Created by Tanner Bennett on 2019-11-25
//  Copyright © 2019 Tanner Bennett. All rights reserved.
//

//-------------------------------//
// This file is for iOS 13+ only //
//    Credit:  DGh0st/FLEXall    //
//-------------------------------//

#import "Interfaces.h"
#import <notify.h>

static NSString *FLEXingActivationName(NSString *bundleIdentifier) {
    return [@"com.pantsthief.flexing.activate." stringByAppendingString:bundleIdentifier];
}

static void FLEXingPresentExplorer(void) {
    if (initialized && manager && show) {
        [manager performSelector:show];
    }
}

%group iOS27StatusBar
%hook STUIStatusBar
- (id)initWithStyle:(NSInteger)style {
    self = %orig;
    if (self) {
        UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc]
            initWithTarget:self action:@selector(flexGestureHandler:)
        ];
        gesture.minimumPressDuration = 0.5;
        gesture.cancelsTouchesInView = NO;
        [self addGestureRecognizer:gesture];
    }
    return self;
}

%new
- (void)flexGestureHandler:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan) {
        return;
    }

    UIApplication *springBoard = UIApplication.sharedApplication;
    id controller = [NSClassFromString(@"SBApplicationController") sharedInstance];
    if (![springBoard respondsToSelector:@selector(_hasForegroundAppWithPID:)] ||
        ![controller respondsToSelector:@selector(runningApplications)]) {
        return;
    }

    for (SBApplication *application in [controller runningApplications]) {
        int pid = [[application processState] pid];
        if (pid > 0 && [springBoard _hasForegroundAppWithPID:pid]) {
            NSString *bundleIdentifier = application.bundleIdentifier;
            if (bundleIdentifier.length) {
                uint32_t result = notify_post(FLEXingActivationName(bundleIdentifier).UTF8String);
            }
            return;
        }
    }

    FLEXingPresentExplorer();
}
%end
%end

%group iOS13StatusBar
// Runs in SpringBoard; forwards status bar events to app
%hook SBMainDisplaySceneLayoutStatusBarView
- (void)_addStatusBarIfNeeded {
    %orig;

    UIView *statusBar = [self valueForKey:@"_statusBar"];
    [statusBar addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(flexGestureHandler:)
    ]];
}

%new
- (void)flexGestureHandler:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [self _statusBarTapped:recognizer type:kFLEXLongPressGesture];
    }
}
%end // SBMainDisplaySceneLayoutStatusBarView

// Runs in apps; receives status bar events
%hook UIStatusBarManager
- (void)handleTapAction:(UIStatusBarTapAction *)action {
    if (action.type == kFLEXLongPressGesture) {
        FLEXingPresentExplorer();
    } else {
        %orig(action);
    }
}
%end // UIStatusBarManager
%end // iOS13StatusBar

%ctor {
    if (@available(iOS 27, *)) {
        NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
        if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
            %init(iOS27StatusBar);
        } else if (bundleIdentifier.length) {
            static int activationToken;
            uint32_t result = notify_register_dispatch(
                FLEXingActivationName(bundleIdentifier).UTF8String,
                &activationToken, dispatch_get_main_queue(), ^(int token) {
                    if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
                        FLEXingPresentExplorer();
                    }
                }
            );
        }
    } else if (@available(iOS 13, *)) {
        %init(iOS13StatusBar);
    }
}
