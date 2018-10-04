#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>

@interface BrainTreePayPalPlugin : CDVPlugin
@property (nonatomic, strong) BTAPIClient *braintreeClient;
- (void)init : (CDVInvokedUrlCommand *)command;
- (void)showPaymentUI : (CDVInvokedUrlCommand *)command;
@end
