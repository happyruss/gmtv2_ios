//
//  IAPHelper.m
//  GuidedMeds
//
//  Created by Mr Russell on 1/20/15.
//  Copyright (c) 2015 Guided Meditation Treks. All rights reserved.
//

#import "IAPHelper.h"
#import <StoreKit/StoreKit.h>

@interface IAPHelper () <SKProductsRequestDelegate, SKPaymentTransactionObserver>
@end

static NSString *INAPP_ASKHIGHER = @"com.russellEricDobda.inAppPurchase.askhigherself";
static NSString *INAPP_CRYSTAL = @"com.russellEricDobda.inAppPurchase.programcrystal";
static NSString *INAPP_HELPANOTHER = @"com.russellEricDobda.inAppPurchase.helpanother";

NSMutableDictionary *productsToRestore;
NSString *const IAPHelperProductPurchasedNotification = @"IAPHelperProductPurchasedNotification";
NSString *const IAPHelperUserCancelLoginNotification = @"IAPHelperUserCancelLoginNotification";
NSString *const IAPHelperUserLoginNotification = @"IAPHelperUserLoginNotification";

@implementation IAPHelper {
    SKProductsRequest * _productsRequest;
    RequestProductsCompletionHandler _completionHandler;
    NSSet * _productIdentifiers;
    NSMutableSet * _purchasedProductIdentifiers;
}

+ (NSString *) inAppNameHelpAnother { return INAPP_HELPANOTHER; }
+ (NSString *) inAppNameCrystal { return INAPP_CRYSTAL; }
+ (NSString *) inAppNameAskHigher { return INAPP_ASKHIGHER; }

+ (IAPHelper *)sharedInstance {
    static IAPHelper * sharedInstance;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSSet * productIdentifiers = [NSSet setWithObjects:
                                          INAPP_ASKHIGHER,
                                          INAPP_CRYSTAL,
                                          INAPP_HELPANOTHER,
                                          nil];
            sharedInstance = [[self alloc] initWithProductIdentifiers:productIdentifiers];
        });
    return sharedInstance;
}

+ (NSString *) downloadableContentPath;
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *directory = [paths objectAtIndex:0];
    directory = [directory stringByAppendingPathComponent:@"Downloads"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:directory] == NO) {
        
        NSError *error;
        if ([fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error] == NO) {
            NSLog(@"Error: Unable to create directory: %@", error);
        }
        
        NSURL *url = [NSURL fileURLWithPath:directory];
        // exclude downloads from iCloud backup
        if ([url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:&error] == NO) {
            NSLog(@"Error: Unable to exclude directory from backup: %@", error);
        }
    }
    return directory;
}

+ (BOOL) productDownloaded:(NSString*)trackId
{
    bool returnVal = true;
    NSMutableArray *audioFilenames = [IAPHelper getAudioFilenames:trackId];
    for (NSString *af in audioFilenames)
    {
        bool fileExists = [[NSFileManager defaultManager] fileExistsAtPath:af];
        if (!fileExists)
        {
            returnVal = NO;
        }
    }
    return returnVal;
}

+ (NSMutableArray*) getAudioFilenames:(NSString*)trackId
{
    NSMutableArray *audioFilenames = [NSMutableArray new];
    
    //Track 1 is in bundle, the rest are downloaded
    if([trackId isEqualToString:@"01"])
    {
        [audioFilenames addObject:[[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"%@%@", trackId, @"binaural"] ofType:@"m4a"]];
        [audioFilenames addObject:[[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"%@%@", trackId, @"nature"] ofType:@"m4a"]];
        [audioFilenames addObject:[[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"%@%@", trackId, @"music"] ofType:@"m4a"]];
        [audioFilenames addObject:[[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"%@%@", trackId, @"voice"] ofType:@"m4a"]];
        [audioFilenames addObject:[[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"%@%@", trackId, @"isochronic"] ofType:@"m4a"]];
    }
    else
    {
        NSString *downloadPath = [IAPHelper downloadableContentPath];
        [audioFilenames addObject:[downloadPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@", trackId, @"binaural.m4a"]]];
        [audioFilenames addObject:[downloadPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@", trackId, @"nature.m4a"]]];
        [audioFilenames addObject:[downloadPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@", trackId, @"music.m4a"]]];
        [audioFilenames addObject:[downloadPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@", trackId, @"voice.m4a"]]];
        [audioFilenames addObject:[downloadPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@", trackId, @"isochronic.m4a"]]];
    }
    return audioFilenames;
}

+ (bool) inAppPurchaseDownloaded:(NSString * ) iapName
{
    NSString *trackId;
    
    if ([iapName isEqualToString:INAPP_ASKHIGHER])
    {
        trackId = @"02";
    }
    else if ([iapName isEqualToString:INAPP_CRYSTAL])
    {
        trackId = @"03";
    }
    else if ([iapName isEqualToString:INAPP_HELPANOTHER])
    {
        trackId = @"04";
    }
    return [IAPHelper productDownloaded:trackId];
}

- (id)initWithProductIdentifiers:(NSSet *)productIdentifiers {
    
    /* / DEBUGGING ONLY!! finish ALL transactions in queue
    SKPaymentQueue* currentQueue = [SKPaymentQueue defaultQueue];
    [currentQueue.transactions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [currentQueue finishTransaction:(SKPaymentTransaction *)obj];
    }];
    */

    if ((self = [super init])) {
        
        // Store product identifiers
        _productIdentifiers = productIdentifiers;
        
        // Check for previously purchased products
        _purchasedProductIdentifiers = [NSMutableSet set];
        for (NSString * productIdentifier in _productIdentifiers) {
            BOOL productPurchased = [[NSUserDefaults standardUserDefaults] boolForKey:productIdentifier];
            if (productPurchased) {
                [_purchasedProductIdentifiers addObject:productIdentifier];
                NSLog(@"Previously purchased: %@", productIdentifier);
            } else {
                NSLog(@"Not purchased: %@", productIdentifier);
            }
        }
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
        
        productsToRestore = [[NSMutableDictionary alloc] initWithCapacity:3];
    }
    return self;
}

- (void)requestProductsWithCompletionHandler:(RequestProductsCompletionHandler)completionHandler {
    _completionHandler = [completionHandler copy];
    _productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:_productIdentifiers];
    _productsRequest.delegate = self;
    [_productsRequest start];
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    
    NSLog(@"Loaded list of products...");
    _productsRequest = nil;
    
    NSArray * skProducts = response.products;
    for (SKProduct * skProduct in skProducts) {
        NSLog(@"Found product: %@ %@ %0.2f",
              skProduct.productIdentifier,
              skProduct.localizedTitle,
              skProduct.price.floatValue);
    }
    
    if (_completionHandler != nil)
    {
        _completionHandler(YES, skProducts);
        _completionHandler = nil;
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    
    NSLog(@"Failed to load list of products.");
    _productsRequest = nil;

    if (_completionHandler != nil)
    {
        _completionHandler(NO, nil);
        _completionHandler = nil;
    }
}

- (BOOL)productPurchased:(NSString *)productIdentifier {
    return [_purchasedProductIdentifiers containsObject:productIdentifier];
}

- (void)buyProduct:(SKProduct *)product {
    
    NSLog(@"Buying %@...", product.productIdentifier);
    
    SKPayment * payment = [SKPayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    
}

- (void)restoreProduct:(SKProduct *)product {
    NSLog(@"Restoring %@...", product.productIdentifier);
    //productToRestore = product.productIdentifier;
    [productsToRestore setObject:[NSNumber numberWithBool:YES] forKey:product.productIdentifier];
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)initProducts
{
    NSLog(@"Initializing product list");
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction * transaction in transactions) {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                if (transaction.downloads)
                {
                    [self completeDownload:transaction];
                }
                else
                {
                    [self completeTransaction:transaction];
                }
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                if(transaction.downloads
                   && [productsToRestore[transaction.payment.productIdentifier] boolValue]
                   && ![IAPHelper inAppPurchaseDownloaded:transaction.payment.productIdentifier])
                    [self restoreDownload:transaction];
                else
                    [self restoreTransaction:transaction];
            default:
                break;
        }
    };
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    NSLog(@"completeTransaction...");
    if (transaction.payment.productIdentifier != nil)
    {
        [self provideContentForProductIdentifier:transaction.payment.productIdentifier];
    }
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)completeDownload:(SKPaymentTransaction *)transaction {
    NSLog(@"completeTransaction...");
    if (transaction.payment.productIdentifier != nil)
    {
        [self provideContentForProductIdentifier:transaction.payment.productIdentifier];
        [[SKPaymentQueue defaultQueue] startDownloads:transaction.downloads];
    }
    else
    {
        //something bad happened; abort
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
}

- (void)restoreTransaction:(SKPaymentTransaction *)transaction {
    NSLog(@"restoreTransaction...");
    if (transaction.originalTransaction.payment.productIdentifier != nil)
    {
        [self provideContentForProductIdentifier:transaction.originalTransaction.payment.productIdentifier];
    }
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)restoreDownload:(SKPaymentTransaction *)transaction {
    NSLog(@"restoreDownload...");
    if (transaction.originalTransaction.payment.productIdentifier != nil)
    {
        [self provideContentForProductIdentifier:transaction.originalTransaction.payment.productIdentifier];
        [[SKPaymentQueue defaultQueue] startDownloads:transaction.downloads];
    }
    else
    {
        //something bad happened; abort
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
    //user clicked cancel when prompted to login to app store
    NSLog(@"<><Canceled!><>");
    [[NSNotificationCenter defaultCenter] postNotificationName:IAPHelperUserCancelLoginNotification object:nil userInfo:nil];
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    [[NSNotificationCenter defaultCenter] postNotificationName:IAPHelperUserLoginNotification object:nil userInfo:nil];
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    
    NSLog(@"failedTransaction...");
    if (transaction.error.code != SKErrorPaymentCancelled)
    {
        NSLog(@"Transaction error: %@", transaction.error.localizedDescription);
    }
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void)provideContentForProductIdentifier:(NSString *)productIdentifier {
    
    [_purchasedProductIdentifiers addObject:productIdentifier];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:productIdentifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads
{
    for (SKDownload *download in downloads)
    {
        switch (download.downloadState) {
            case SKDownloadStateActive:
            {
                NSLog(@"Download progress = %f",
                      download.progress);
                NSLog(@"Download time = %f",
                      download.timeRemaining);
                
                NSMutableArray *notificationObject = [NSMutableArray new];
                [notificationObject addObject:download.contentIdentifier];
                NSString *percent = [NSString stringWithFormat:@"%.f%%",download.progress * 100];
                [notificationObject addObject:percent];
                [[NSNotificationCenter defaultCenter] postNotificationName:IAPHelperProductPurchasedNotification object:notificationObject userInfo:nil];
                break;
            }
            case SKDownloadStateWaiting:
                NSLog(@"Download state waiting");
                break;
            case SKDownloadStateCancelled:
                NSLog(@"Download state cancelled");
                break;
            case SKDownloadStateFailed:
                NSLog(@"Download state failed");
                break;
            case SKDownloadStatePaused:
                NSLog(@"Download state paused");
                break;
            case SKDownloadStateFinished:
                NSLog(@"Download state finished");
                [self processDownload:download];
                [[SKPaymentQueue defaultQueue] finishTransaction: download.transaction];
            default:
                break;
        }
    }
}

- (void) processDownload:(SKDownload*)download;
{
    // convert url to string, suitable for NSFileManager
    NSString *path = [download.contentURL path];
    
    // files are in Contents directory
    path = [path stringByAppendingPathComponent:@"Contents"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *files = [fileManager contentsOfDirectoryAtPath:path error:&error];
    NSString *dir = [IAPHelper downloadableContentPath];
    
    for (NSString *file in files) {
        
        NSString *fullPathSrc = [path stringByAppendingPathComponent:file];
        NSString *fullPathDst = [dir stringByAppendingPathComponent:file];
        
        // not allowed to overwrite files - remove destination file
        [fileManager removeItemAtPath:fullPathDst error:NULL];
        
        if ([fileManager moveItemAtPath:fullPathSrc toPath:fullPathDst error:&error] == NO) {
            NSLog(@"Error: unable to move item: %@", error);
        }
    }
    
    NSMutableArray *notificationObject = [NSMutableArray new];
    [notificationObject addObject:download.contentIdentifier];
    [[NSNotificationCenter defaultCenter] postNotificationName:IAPHelperProductPurchasedNotification object:notificationObject userInfo:nil];
}


@end
