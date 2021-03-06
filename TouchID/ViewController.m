//
//  ViewController.m
//  TouchID
//
//  Created by Marvs Temp User on 21/03/2016.
//  Copyright © 2016 Marvs Temp User. All rights reserved.
//

#import "ViewController.h"
#import "KeychainItemWrapper.h"
#import <LocalAuthentication/LocalAuthentication.h>


static const NSString *defaultSSIDDATA = @"<43797350 726f6a65 637435>";
static const NSString *defaultSSID = @"CysProject5";

@import SystemConfiguration.CaptiveNetwork;

@interface ViewController ()

@property (nonatomic, retain) IBOutlet UIView *flashView;
@property (nonatomic, retain) IBOutlet UILabel *clockView;

@end

@implementation ViewController

#pragma mark - authentication methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self startClock];
    [self flashColorAlertIsSuccess:YES];
}

- (void)startClock
{
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                      target:self
                                                    selector:@selector(updateClock)
                                                    userInfo:nil repeats:YES];
    [timer fire];
}

- (void)updateClock
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"EEE, MMM d, yyyy\na h:mm:ss"];
    self.clockView.text = [formatter stringFromDate:[NSDate date]];
}

- (void)authenticateButtonTapped:(id)sender
{
    LAContext *context = [[LAContext alloc] init];
    context.localizedFallbackTitle = @"";
    NSError *error;
    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                             error:&error]) {
        [self performBiometricAuthenticationWithContext:context];
    } else {
        [self evaluateWithUserPasscodeForContext:context];
    }
}

- (void)performBiometricAuthenticationWithContext:(LAContext *)context
{
    if (![self isConnectedToAuthorizedNetwork]) {
        [self showNotConnectedToOfficeNetworkWithCompletionBlock:nil];
        return;
    } else {
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                localizedReason:@"Scan your fingerprint on the home button to authenticate."
                          reply:^(BOOL success, NSError * _Nullable error) {
                              if (error) {
                                  if (error.code == LAErrorUserFallback) {
                                      [self evaluateWithUserPasscodeForContext:context];
                                      return;
                                  }
                                  [self handleAuthenticationError:error];
                                  return;
                              }
                              if (success) {
                                  [self handleAuthenticationSuccess];
                              }
                          }];
    }
}

- (void)evaluateWithUserPasscodeForContext:(LAContext *)context
{
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
            localizedReason:@"Please Enter your PassCode"
                      reply:^(BOOL success, NSError * _Nullable error) {
                          if (success) {
                              [self handleAuthenticationSuccess];
                              return;
                          } else {
                              [self handleAuthenticationError:error];
                          }
                      }];
}

- (void)handleAuthenticationSuccess
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"TiD: Success");
        [self flashColorAlertIsSuccess:YES];
        [self showConfirmAuthorizedWithCompletionBlock:nil];
    });
}

- (void)handleAuthenticationError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"TiD: Error %ld",(long)error.code);
        [self flashColorAlertIsSuccess:NO];
        if (error.code == LAErrorUserCancel) {
            return;
        }
        [self showErrorAlertForError:error
                 withCompletionBlock:nil];
    });
}


#pragma mark - SSID methods

- (NSDictionary *)fetchSSIDInfo
{
    NSArray *interfaceNames = CFBridgingRelease(CNCopySupportedInterfaces());
    NSLog(@"%s: Supported Interfaces: %@", __func__, interfaceNames);
    
    NSDictionary *SSIDInfo;
    
    for (NSString *interfaceName in interfaceNames) {
        SSIDInfo = CFBridgingRelease(CNCopyCurrentNetworkInfo((__bridge CFStringRef)interfaceName));
        NSLog(@"%s: %@ => %@", __func__, interfaceName, SSIDInfo);
        
        BOOL isNotEmpty = (SSIDInfo.count > 0);
        if (isNotEmpty) {
            break;
        }
    }
//    NSLog(@"SSIDInfo = %@", SSIDInfo);
    return SSIDInfo;
}

- (BOOL)isConnectedToAuthorizedNetwork
{
    return [defaultSSIDDATA isEqualToString:[NSString stringWithFormat:@"%@",[[self fetchSSIDInfo] objectForKey:@"SSIDDATA"]]];
}


#pragma mark - Alert View Showing Methods

- (UIAlertAction *)okActionWithAlertController:(UIAlertController *)alert
{
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"Ok"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
                                                         [alert dismissViewControllerAnimated:NO
                                                                                   completion:nil];
                                                     }];
    return okAction;
}

- (void)showNotConnectedToOfficeNetworkWithCompletionBlock:(void(^)())completion
{
    NSString *connectErrorMessage = [NSString stringWithFormat:@"You're not connected to your office network!\nYou are currently connected to \"%@\". Please connect to \"%@\" Network to proceed.", [[self fetchSSIDInfo] objectForKey:@"SSID"], defaultSSID];
    
    if (![[self fetchSSIDInfo] objectForKey:@"SSID"]) {
        connectErrorMessage = [NSString stringWithFormat:@"You're not connected to your office network!\nPlease connect to \"%@\" Network to proceed.", defaultSSID];
    }
    UIAlertController *connectErrorAlert = [UIAlertController alertControllerWithTitle:@"Failed"
                                                                               message:connectErrorMessage
                                                                        preferredStyle:UIAlertControllerStyleAlert];
    [connectErrorAlert addAction:[self okActionWithAlertController:connectErrorAlert]];
    [self presentViewController:connectErrorAlert
                       animated:NO
                     completion:completion];
}

- (void)showConfirmAuthorizedWithCompletionBlock:(void(^)())completion
{
    NSString *message = [NSString stringWithFormat:@"Authentication Successful! Your Device ID for Vendor is : %@", [[UIDevice currentDevice].identifierForVendor  UUIDString]];
    UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"Success"
                                                                          message:message
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    [successAlert addAction:[self okActionWithAlertController:successAlert]];
    [self presentViewController:successAlert
                       animated:NO
                     completion:completion];
}

- (void)showErrorAlertForError:(NSError *)error
           withCompletionBlock:(void(^)())completion
{
    UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                        message:error.localizedDescription
                                                                 preferredStyle:UIAlertControllerStyleAlert];
    [errorAlert addAction:[self okActionWithAlertController:errorAlert]];
    [self presentViewController:errorAlert
                       animated:NO
                     completion:nil];
}

- (void)showDeviceNotCapableAlertWithCompletionBlock:(void(^)())completion
{
    [self flashColorAlertIsSuccess:NO];
    UIAlertController *notCapableAlert = [UIAlertController alertControllerWithTitle:@"Info"
                                                                             message:@"Your device is not capable of Touch Id Authentication"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [notCapableAlert addAction:[self okActionWithAlertController:notCapableAlert]];
    [self presentViewController:notCapableAlert
                       animated:NO
                     completion:completion];
}

- (void)flashColorAlertIsSuccess:(BOOL)successful
{
    UIColor *flashColor = successful ? [UIColor greenColor] : [UIColor redColor];
    [self.flashView setBackgroundColor:flashColor];
    [UIView animateWithDuration:2.0
                     animations:^{
                         self.flashView.backgroundColor = [UIColor whiteColor];
                     }
                     completion:^(BOOL finished){
                         
                     }];
}


@end
