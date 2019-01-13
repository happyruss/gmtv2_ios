//
//  IAPHelper.h
//  GuidedMeds
//
//  Created by Mr Russell on 1/20/15.
//  Copyright (c) 2015 Guided Meditation Treks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>


UIKIT_EXTERN NSString *const IAPHelperProductPurchasedNotification;
UIKIT_EXTERN NSString *const IAPHelperUserCancelLoginNotification;
UIKIT_EXTERN NSString *const IAPHelperUserLoginNotification;

typedef void (^RequestProductsCompletionHandler)(BOOL success, NSArray * products);

@interface IAPHelper : NSObject


- (id)initWithProductIdentifiers:(NSSet *)productIdentifiers;
- (void)requestProductsWithCompletionHandler:(RequestProductsCompletionHandler)completionHandler;

- (void)buyProduct:(SKProduct *)product;
- (void)restoreProduct:(SKProduct *)product;
- (void)initProducts;

- (BOOL)productPurchased:(NSString *)productIdentifier;

+ (IAPHelper *)sharedInstance;
+ (NSString *) downloadableContentPath;
+ (NSMutableArray*) getAudioFilenames:(NSString*)trackId;

+ (NSString *) inAppNameAskHigher;
+ (NSString *) inAppNameCrystal;
+ (NSString *) inAppNameHelpAnother;

+ (BOOL) productDownloaded:(NSString*) trackId;
+ (bool) inAppPurchaseDownloaded:(NSString * ) iapName;

@end
