/*
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 *
 */

#import "CDVOrientation.h"
#import <Cordova/CDVViewController.h>
#import <objc/message.h>
#import <objc/runtime.h>

// Global variable to store the current orientation mask
// Default to all orientations (UIInterfaceOrientationMaskAll)
UIInterfaceOrientationMask cdvOrientationCurrentMask = UIInterfaceOrientationMaskAll;

// Flag to track if swizzling has been done
static BOOL cdvOrientationSwizzled = NO;

// Original method implementation pointer
static IMP cdvOrientationOriginalIMP = NULL;

// Swizzled method that returns our stored orientation mask
UIInterfaceOrientationMask CDVOrientation_swizzled_supportedInterfaceOrientations(id self, SEL _cmd) {
    NSLog(@"[CDVOrientation] Swizzled supportedInterfaceOrientations called, returning mask: %lu", (unsigned long)cdvOrientationCurrentMask);
    return cdvOrientationCurrentMask;
}

@interface CDVOrientation () {}
@end

@implementation CDVOrientation

+ (void)setupOrientationSwizzling {
    if (cdvOrientationSwizzled) {
        NSLog(@"[CDVOrientation] Swizzling already done, skipping");
        return;
    }

    NSLog(@"[CDVOrientation] Setting up orientation swizzling for CDVViewController");

    Class vcClass = [CDVViewController class];
    SEL originalSelector = @selector(supportedInterfaceOrientations);
    Method originalMethod = class_getInstanceMethod(vcClass, originalSelector);

    if (originalMethod) {
        // Store original implementation
        cdvOrientationOriginalIMP = method_getImplementation(originalMethod);
        NSLog(@"[CDVOrientation] Found original supportedInterfaceOrientations method");

        // Replace with our implementation
        method_setImplementation(originalMethod, (IMP)CDVOrientation_swizzled_supportedInterfaceOrientations);
        NSLog(@"[CDVOrientation] Swizzled supportedInterfaceOrientations successfully");
    } else {
        // Add the method if it doesn't exist
        NSLog(@"[CDVOrientation] supportedInterfaceOrientations method not found, adding it");
        class_addMethod(vcClass, originalSelector, (IMP)CDVOrientation_swizzled_supportedInterfaceOrientations, "Q@:");
        NSLog(@"[CDVOrientation] Added supportedInterfaceOrientations method");
    }

    cdvOrientationSwizzled = YES;
}

- (void)pluginInitialize {
    [super pluginInitialize];
    NSLog(@"[CDVOrientation] Plugin initialized, setting up swizzling");
    [CDVOrientation setupOrientationSwizzling];
}


-(void)handleBelowEqualIos15WithOrientationMask:(NSInteger) orientationMask viewController: (CDVViewController*) vc result:(NSMutableArray*) result
{
    NSLog(@"[CDVOrientation] handleBelowEqualIos15 - orientationMask: %ld", (long)orientationMask);
    NSValue *value;
    if (orientationMask != 15) {
        if (!_isLocked) {
            _lastOrientation = [UIApplication sharedApplication].statusBarOrientation;
            NSLog(@"[CDVOrientation] Saving lastOrientation: %ld", (long)_lastOrientation);
        }
        UIInterfaceOrientation deviceOrientation = [UIApplication sharedApplication].statusBarOrientation;
        NSLog(@"[CDVOrientation] Current deviceOrientation: %ld", (long)deviceOrientation);
        if(orientationMask == 8  || (orientationMask == 12  && !UIInterfaceOrientationIsLandscape(deviceOrientation))) {
            value = [NSNumber numberWithInt:UIInterfaceOrientationLandscapeLeft];
            NSLog(@"[CDVOrientation] Setting to LandscapeLeft");
        } else if (orientationMask == 4){
            value = [NSNumber numberWithInt:UIInterfaceOrientationLandscapeRight];
            NSLog(@"[CDVOrientation] Setting to LandscapeRight");
        } else if (orientationMask == 1 || (orientationMask == 3 && !UIInterfaceOrientationIsPortrait(deviceOrientation))) {
            value = [NSNumber numberWithInt:UIInterfaceOrientationPortrait];
            NSLog(@"[CDVOrientation] Setting to Portrait");
        } else if (orientationMask == 2) {
            value = [NSNumber numberWithInt:UIInterfaceOrientationPortraitUpsideDown];
            NSLog(@"[CDVOrientation] Setting to PortraitUpsideDown");
        }
    } else {
        NSLog(@"[CDVOrientation] Unlocking orientation, restoring lastOrientation: %ld", (long)_lastOrientation);
        if (_lastOrientation != UIInterfaceOrientationUnknown) {
            [[UIDevice currentDevice] setValue:[NSNumber numberWithInt:_lastOrientation] forKey:@"orientation"];
            [UINavigationController attemptRotationToDeviceOrientation];
        }
    }
    if (value != nil) {
        _isLocked = true;
        NSLog(@"[CDVOrientation] Orientation locked");
        [[UIDevice currentDevice] setValue:value forKey:@"orientation"];
    } else {
        _isLocked = false;
        NSLog(@"[CDVOrientation] Orientation unlocked");
    }
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 160000
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
// this will stop it complaining about new iOS16 APIs being used.
-(void)handleAboveEqualIos16WithOrientationMask:(NSInteger) orientationMask viewController: (CDVViewController*) vc result:(NSMutableArray*) result
{
    NSLog(@"[CDVOrientation] handleAboveEqualIos16 - orientationMask: %ld", (long)orientationMask);
    NSObject *value;
    // oritentationMask 15 is "unlock" the orientation lock.
    if (orientationMask != 15) {
        if (!_isLocked) {
            _lastOrientation = [UIApplication sharedApplication].statusBarOrientation;
            NSLog(@"[CDVOrientation] iOS16+ Saving lastOrientation: %ld", (long)_lastOrientation);
        }
        UIInterfaceOrientation deviceOrientation = [UIApplication sharedApplication].statusBarOrientation;
        NSLog(@"[CDVOrientation] iOS16+ Current deviceOrientation: %ld", (long)deviceOrientation);
        if(orientationMask == 8  || (orientationMask == 12  && !UIInterfaceOrientationIsLandscape(deviceOrientation))) {
            value = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskLandscapeLeft];
            NSLog(@"[CDVOrientation] iOS16+ Setting to LandscapeLeft via Scene API");
        } else if (orientationMask == 4){
            value = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskLandscapeRight];
            NSLog(@"[CDVOrientation] iOS16+ Setting to LandscapeRight via Scene API");
        } else if (orientationMask == 1 || (orientationMask == 3 && !UIInterfaceOrientationIsPortrait(deviceOrientation))) {
            value = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskPortrait];
            NSLog(@"[CDVOrientation] iOS16+ Setting to Portrait via Scene API");
        } else if (orientationMask == 2) {
            value = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskPortraitUpsideDown];
            NSLog(@"[CDVOrientation] iOS16+ Setting to PortraitUpsideDown via Scene API");
        }
    } else {
        NSLog(@"[CDVOrientation] iOS16+ Unlocking orientation");
        // Note: Cordova iOS 8 removed supportedOrientations property
        // Orientation unlock is handled by the Scene API geometry preferences
    }
    if (value != nil) {
        _isLocked = true;
        NSLog(@"[CDVOrientation] iOS16+ Orientation locked, requesting geometry update");
        UIWindowScene *scene = (UIWindowScene*)[[UIApplication.sharedApplication connectedScenes] anyObject];
        NSLog(@"[CDVOrientation] iOS16+ Using scene: %@", scene);
        [scene requestGeometryUpdateWithPreferences:(UIWindowSceneGeometryPreferencesIOS*)value errorHandler:^(NSError * _Nonnull error) {
            NSLog(@"[CDVOrientation] iOS16+ Failed to change orientation: %@ %@", error, [error userInfo]);
        }];
        NSLog(@"[CDVOrientation] iOS16+ Geometry update requested successfully");
    } else {
        _isLocked = false;
        NSLog(@"[CDVOrientation] iOS16+ Orientation unlocked");
    }
}
#pragma clang diagnostic pop

-(void)handleWithOrientationMask:(NSInteger) orientationMask viewController: (CDVViewController*) vc result:(NSMutableArray*) result
{
    if (@available(iOS 16.0, *)) {
        NSLog(@"[CDVOrientation] Using iOS 16+ handler");
        [self handleAboveEqualIos16WithOrientationMask:orientationMask viewController:vc result:result];
        // always double check the supported interfaces, so we update if needed
        // but do it right at the end here to avoid the "double" rotation issue reported in
        // https://github.com/apache/cordova-plugin-screen-orientation/pull/107
        [self.viewController setNeedsUpdateOfSupportedInterfaceOrientations];
        NSLog(@"[CDVOrientation] Called setNeedsUpdateOfSupportedInterfaceOrientations");
    } else {
        NSLog(@"[CDVOrientation] Using iOS 15 and below handler");
        [self handleBelowEqualIos15WithOrientationMask:orientationMask viewController:vc result:result];
    }

}
#else
-(void)handleWithOrientationMask:(NSInteger) orientationMask viewController: (CDVViewController*) vc result:(NSMutableArray*) result
{
    [self handleBelowEqualIos15WithOrientationMask:orientationMask viewController:vc result:result];
}
#endif


-(void)screenOrientation:(CDVInvokedUrlCommand *)command
{
    NSLog(@"[CDVOrientation] screenOrientation called");
    CDVPluginResult* pluginResult;
    NSInteger orientationMask = [[command argumentAtIndex:0] integerValue];
    NSLog(@"[CDVOrientation] Requested orientationMask: %ld (1=portrait, 2=portraitUpsideDown, 4=landscapeRight, 8=landscapeLeft, 15=unlock)", (long)orientationMask);
    CDVViewController* vc = (CDVViewController*)self.viewController;
    NSMutableArray* result = [[NSMutableArray alloc] init];

    if(orientationMask & 1) {
        [result addObject:[NSNumber numberWithInt:UIInterfaceOrientationPortrait]];
    }
    if(orientationMask & 2) {
        [result addObject:[NSNumber numberWithInt:UIInterfaceOrientationPortraitUpsideDown]];
    }
    if(orientationMask & 4) {
        [result addObject:[NSNumber numberWithInt:UIInterfaceOrientationLandscapeRight]];
    }
    if(orientationMask & 8) {
        [result addObject:[NSNumber numberWithInt:UIInterfaceOrientationLandscapeLeft]];
    }
    NSLog(@"[CDVOrientation] Supported orientations array: %@", result);

    // Update the global orientation mask for the swizzled supportedInterfaceOrientations method
    // This is critical for iOS 16+ where the Scene API queries the view controller's supported orientations
    UIInterfaceOrientationMask newMask = 0;
    if (orientationMask & 1) newMask |= UIInterfaceOrientationMaskPortrait;
    if (orientationMask & 2) newMask |= UIInterfaceOrientationMaskPortraitUpsideDown;
    if (orientationMask & 4) newMask |= UIInterfaceOrientationMaskLandscapeRight;
    if (orientationMask & 8) newMask |= UIInterfaceOrientationMaskLandscapeLeft;

    // If unlocking (mask 15), allow all orientations
    if (orientationMask == 15) {
        newMask = UIInterfaceOrientationMaskAll;
    }

    cdvOrientationCurrentMask = newMask;
    NSLog(@"[CDVOrientation] Updated global orientation mask to: %lu", (unsigned long)cdvOrientationCurrentMask);

    // Cordova iOS 8 removed supportedOrientations property from CDVViewController
    // Use iOS 16+ Scene API or UIDevice setValue hack for older iOS versions
    NSLog(@"[CDVOrientation] Processing orientation change (Cordova iOS 8+ compatible)");

    if ([UIDevice currentDevice] != nil) {
        [self handleWithOrientationMask:orientationMask viewController:vc result:result];
    }

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    NSLog(@"[CDVOrientation] Orientation change completed successfully");

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

}

@end
