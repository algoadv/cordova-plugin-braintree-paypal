#import "BrainTreePayPalPlugin.h"
#import <objc/runtime.h>
#import <BraintreeCore/BTAPIClient.h>
#import <BraintreePayPal/BraintreePayPal.h>
#import <Cordova/CDVPluginResult.h>
#import <Foundation/Foundation.h>
#include <sys/types.h>
#include <sys/sysctl.h>

@implementation BrainTreePayPalPlugin
    
    NSString *dropInUIcallbackId;

    - (void)init : (CDVInvokedUrlCommand *)command 
    {
        NSLog(@"[BrainTreePlugin] Starting init");

        if ([command.arguments count] != 1) {
            NSLog(@"[BrainTreePlugin] Token has not been passed");
            CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"A token is required."];
            [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
            return;
        }
        
        // Obtain the arguments.
        self.token = [command.arguments objectAtIndex:0];
        if (!self.token) {
            NSLog(@"[BrainTreePlugin] Empty token passed");
            CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"A token is required."];
            [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
            return;
        }
        
        NSLog(@"[BrainTreePlugin] Initializing with token %@", self.token);
        self.braintreeClient = [[BTAPIClient alloc] initWithAuthorization:self.token];
        
        if (!self.braintreeClient) {
            NSLog(@"[BrainTreePlugin] Failed initializing the client");
            CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"The Braintree client failed to initialize."];
            [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
            return;
        }
        
        NSString *bundle_id = [NSBundle mainBundle].bundleIdentifier;
        bundle_id = [bundle_id stringByAppendingString:@".payments"];
        
        [BTAppSwitch setReturnURLScheme:bundle_id];
        
        NSLog(@"[BrainTreePlugin] Init Done. Returning callback");

        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
    }
    
    - (void)showPaymentUI : (CDVInvokedUrlCommand *)command 
    {
        if (!self.braintreeClient) {
            CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"The Braintree client must first be initialized via BraintreePlugin.initialize(token)"];
            [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
            return;
        }
        
        // Ensure we have the correct number of arguments.
        if ([command.arguments count] < 1) {
            CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"amount required."];
            [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
            return;
        }

        NSString* amount = (NSString *)[command.arguments objectAtIndex:0];
        if ([amount isKindOfClass:[NSNumber class]]) {
            amount = [(NSNumber *)amount stringValue];
        }
        if (!amount) {
            CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"amount is required."];
            [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
            return;
        }
        
        NSString* currency = [command.arguments objectAtIndex:1];

        // Save off the Cordova callback ID so it can be used in the completion handlers.
        dropInUIcallbackId = command.callbackId;

        BTPayPalDriver *payPalDriver = [[BTPayPalDriver alloc] initWithAPIClient:self.braintreeClient];
        payPalDriver.viewControllerPresentingDelegate = self;
        payPalDriver.appSwitchDelegate = self; // Optional

        // Specify the transaction amount here.
        BTPayPalRequest *request= [[BTPayPalRequest alloc] initWithAmount:amount];
        request.currencyCode = currency;

        [payPalDriver requestOneTimePayment:request completion:^(BTPayPalAccountNonce * _Nullable tokenizedPayPalAccount, NSError * _Nullable error) {
            if (tokenizedPayPalAccount) {
                // NSLog(@"Got a nonce: %@", tokenizedPayPalAccount.nonce);
                NSLog(@"[BrainTreePlugin] Payment authorized");
                // Payment Authorized
                if (dropInUIcallbackId) {
                    NSLog(@"[BrainTreePlugin] Returning success result");
                    NSDictionary *dictionary = [self getPaymentUINonceResult:tokenizedPayPalAccount];
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
                    
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:dropInUIcallbackId];
                    dropInUIcallbackId = nil;
                }
            } else if (error) {
                // Handle error here...
                NSLog(@"[BrainTreePlugin] Paymenet error");
                if(dropInUIcallbackId) {
                    NSLog(@"[BrainTreePlugin] Returning error result");
                    NSString *errorMessage = [error localizedDescription];

                    CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
                    [self.commandDelegate sendPluginResult:res callbackId:dropInUIcallbackId];
                    dropInUIcallbackId = nil;
                    return;
                }
            } else {
                // Buyer canceled payment approval
                NSLog(@"[BrainTreePlugin] Payment canceled");
                if (dropInUIcallbackId) {
                    NSLog(@"[BrainTreePlugin] Returning cancelation result");
                    NSDictionary *dictionary = @{ @"userCancelled": @YES };
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                                messageAsDictionary:dictionary];

                    [self.commandDelegate sendPluginResult:pluginResult callbackId:dropInUIcallbackId];
                    dropInUIcallbackId = nil;
                }
            }
        }];
    }

    #pragma mark - Helpers
    /**
    * Helper used to return a dictionary of values from the given payment method nonce.
    * Handles paypal nonce.
    */
    - (NSDictionary*)getPaymentUINonceResult:(BTPayPalAccountNonce *)payPalAccountNonce {
        NSDictionary *dictionary = @{ @"userCancelled": @NO,
                                    
                                    // Standard Fields
                                    @"nonce": payPalAccountNonce.nonce,
                                    @"type": payPalAccountNonce.type,
                                    @"localizedDescription": payPalAccountNonce.localizedDescription,
                                    
                                    // BTPayPalAccountNonce
                                    @"payPalAccount": !payPalAccountNonce ? [NSNull null] : @{
                                            @"email": payPalAccountNonce.email,
                                            @"firstName": (payPalAccountNonce.firstName == nil ? [NSNull null] : payPalAccountNonce.firstName),
                                            @"lastName": (payPalAccountNonce.lastName == nil ? [NSNull null] : payPalAccountNonce.lastName),
                                            @"phone": (payPalAccountNonce.phone == nil ? [NSNull null] : payPalAccountNonce.phone),
                                            @"clientMetadataId":  (payPalAccountNonce.clientMetadataId == nil ? [NSNull null] : payPalAccountNonce.clientMetadataId),
                                            @"payerId": (payPalAccountNonce.payerId == nil ? [NSNull null] : payPalAccountNonce.payerId),
                                    }
                                };
        return dictionary;
    }
@end
