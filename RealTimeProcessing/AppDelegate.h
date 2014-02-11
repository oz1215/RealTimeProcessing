//
//  AppDelegate.h
//  RealTimeProcessing
//
//  Created by hirai.yuki on 2013/04/07.
//  Copyright (c) 2013年 hirai.yuki. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate> {
    BOOL isStationary;
}
@property (nonatomic) BOOL isStationary;

@property (strong, nonatomic) UIWindow *window;

@end
