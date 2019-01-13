//
//  PurchaseViewController.m
//  GuidedMeds
//
//  Created by Mr Russell on 1/20/15.
//  Copyright (c) 2015 Guided Meditation Treks. All rights reserved.
//

#import "PurchaseViewController.h"
#import "IAPHelper.h"
#import "containerViewController.h"
#import <StoreKit/StoreKit.h>

@interface PurchaseViewController ()
{
    NSArray *_products;
}
@end

@implementation PurchaseViewController

NSNumberFormatter * _priceFormatter;

NSMutableDictionary *dict;

bool userLoggedIn;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loginCanceled:) name:IAPHelperUserCancelLoginNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loginCompleted:) name:IAPHelperUserLoginNotification object:nil];
    
    [IAPHelper sharedInstance];

    self.title = @"Guided Meditation Treks v1";
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
    [self reload];
    [self.refreshControl beginRefreshing];
    
    _priceFormatter = [[NSNumberFormatter alloc] init];
    [_priceFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [_priceFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    
    dict = [[NSMutableDictionary alloc]initWithCapacity:3];
}

- (void)reload {
    _products = nil;
    [self.tableView reloadData];
    
    
    [[IAPHelper sharedInstance] requestProductsWithCompletionHandler:^(BOOL success, NSArray *products)
    {
        if (success) {
            _products = products;
            [self.tableView reloadData];
        }
        else
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:@"Error connecting to App Store for products."
                                                           delegate:self
                                                  cancelButtonTitle:@"Cancel"
                                                  otherButtonTitles:@"Retry", nil];
            [alert show];

        }
        [self.refreshControl endRefreshing];
    }];
}

- (void)alertView:(UIAlertView *)alertView
clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1)
        [self reload];
    else
    {
        containerViewController *p = ((containerViewController *) self.parentViewController);
        [p doneButtonPressed:nil];
    }
}


#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

// 5
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _products.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    [cell setBackgroundColor:[UIColor whiteColor]];
    
    
    SKProduct * product = (SKProduct *) _products[indexPath.row];
    
    if (product.localizedTitle == nil)
    {
        cell.textLabel.text = product.description;
        cell.detailTextLabel.text = @"Error loading locale information. The product does not have a localized description or price information. Contact Support.";
    }
    else
    {
        cell.textLabel.text = product.localizedTitle;
        [_priceFormatter setLocale:product.priceLocale];
        cell.detailTextLabel.text = [[[_priceFormatter stringFromNumber:product.price] stringByAppendingString:@": "] stringByAppendingString:product.localizedDescription];
    }
    
    if (!userLoggedIn)
    {
        UIButton *buyButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        buyButton.frame = CGRectMake(0, 0, 72, 37);
        [buyButton setTitle:@"Login" forState:UIControlStateNormal];
        buyButton.tag = indexPath.row;
        [buyButton addTarget:self action:@selector(loginButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = buyButton;
    }
     
    else  if ([[IAPHelper sharedInstance] productPurchased:product.productIdentifier])
    {
        if ([IAPHelper inAppPurchaseDownloaded:product.productIdentifier])
        {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            cell.accessoryView = nil;
        }
        else
        {
            NSString *downloadStatus = [dict objectForKey:product.productIdentifier];
            
            if (downloadStatus == nil)
            {
                UIButton *restoreButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
                restoreButton.frame = CGRectMake(0, 0, 72, 37);
                [restoreButton setTitle:@"Restore" forState:UIControlStateNormal];
                restoreButton.tag = indexPath.row;
                [restoreButton addTarget:self action:@selector(restoreButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.accessoryView = restoreButton;
            }
            else
            {
                UIButton *statusButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
                statusButton.frame = CGRectMake(0, 0, 72, 37);
                [statusButton setTitle:downloadStatus forState:UIControlStateNormal];
                statusButton.tag = indexPath.row;
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.accessoryView = statusButton;

                /*
                UILabel *downloadLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, 72,37)];
                [downloadLabel setText:downloadStatus];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.accessoryView = downloadLabel;
                 */
            }
        }
    }
    else
    {
        UIButton *buyButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        buyButton.frame = CGRectMake(0, 0, 72, 37);
        [buyButton setTitle:@"Buy" forState:UIControlStateNormal];
        buyButton.tag = indexPath.row;
        [buyButton addTarget:self action:@selector(buyButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = buyButton;
    }
    
    return cell;
}

- (void)loginButtonTapped:(id)sender {
    NSLog(@"Logging in...");
    [[IAPHelper sharedInstance] initProducts];
}

- (void)buyButtonTapped:(id)sender {
    
    UIButton *buyButton = (UIButton *)sender;
    SKProduct *product = _products[buyButton.tag];
    
    NSLog(@"Buying %@...", product.productIdentifier);
    [[IAPHelper sharedInstance] buyProduct:product];
    
}

- (void)restoreButtonTapped:(id)sender {
    
    UIButton *restoreButton = (UIButton *)sender;
    SKProduct *product = _products[restoreButton.tag];
    
    NSLog(@"Restoring %@...", product.productIdentifier);
    [[IAPHelper sharedInstance] restoreProduct:product];
}


- (void)viewWillAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(productPurchased:) name:IAPHelperProductPurchasedNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loginCanceled:(NSNotification *)notification {
    //User Cancelled their login, so they should be shown login instead of buy/restore
    userLoggedIn = NO;
    [self reload];
}
- (void)loginCompleted:(NSNotification *)notification {
    //User login, so they should be shown buy/restore
    userLoggedIn = YES;
    [self reload];
}

- (void)productPurchased:(NSNotification *)notification {
    
    NSArray *notificationObject = notification.object;
    NSInteger sz = notificationObject.count;
    NSString * productIdentifier = notificationObject[0];

    if (sz == 1)
    {
        //Completed
        [dict removeObjectForKey:notificationObject[0]];

        [_products enumerateObjectsUsingBlock:^(SKProduct * product, NSUInteger idx, BOOL *stop) {
            if ([product.productIdentifier isEqualToString:productIdentifier]) {
                [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
                *stop = YES;
            }
        }];
    }
    else
    {
        [dict setObject:[NSString stringWithString:notificationObject[1]] forKey:notificationObject[0]];
        [_products enumerateObjectsUsingBlock:^(SKProduct * product, NSUInteger idx, BOOL *stop) {
            if ([product.productIdentifier isEqualToString:productIdentifier]) {
                [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                *stop = YES;
            }
        }];
    }
}

@end