//
//  AppDelegate.m
//  TestDemo
//
//  Created by qianxx on 16/7/6.
//  Copyright © 2016年 pby. All rights reserved.
//

#import "AppDelegate.h"
#import "LoginViewController.h"

@interface AppDelegate ()

@property (nonatomic, assign, getter=isUserLogin) BOOL userLogin;

@end


@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    if (!self.isUserLogin) {
        LoginViewController *login = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"LoginViewController"];
        self.window.rootViewController = login;
    }
    
    return YES;
}



@end
