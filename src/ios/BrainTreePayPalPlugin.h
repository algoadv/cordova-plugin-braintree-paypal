#import <Foundation/Foundation.h>
#import <BraintreeCore/BTAPIClient.h>
#import <Cordova/CDVPlugin.h>

@interface BrainTreePayPalPlugin : CDVPlugin
@property (nonatomic, strong) BTAPIClient *braintreeClient;
@property NSString *token;
- (void)init : (CDVInvokedUrlCommand *)command;
- (void)showPaymentUI : (CDVInvokedUrlCommand *)command;
@end
