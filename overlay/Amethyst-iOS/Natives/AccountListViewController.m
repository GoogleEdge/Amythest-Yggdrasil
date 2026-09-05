#import <AuthenticationServices/AuthenticationServices.h>

#import "authenticator/BaseAuthenticator.h"
#import "authenticator/YggdrasilAuthenticator.h"
#import "AccountListViewController.h"
#import "AFNetworking.h"
#import "AmethystMD3Theme.h"
#import "LauncherPreferences.h"
#import "UIImageView+AFNetworking.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

@interface AccountListViewController()<ASWebAuthenticationPresentationContextProviding>

@property(nonatomic, strong) NSMutableArray *accountList;
@property(nonatomic) ASWebAuthenticationSession *authVC;

- (void)handleYggdrasilStatus:(id)status
                      success:(BOOL)success
                       forCell:(UITableViewCell *)cell
                 authenticator:(YggdrasilAuthenticator *)authenticator;
- (void)presentYggdrasilProfilePicker:(NSArray *)profiles
                        authenticator:(YggdrasilAuthenticator *)authenticator
                               forCell:(UITableViewCell *)cell;
- (void)finishYggdrasilLoginForCell:(UITableViewCell *)cell;
- (void)cancelYggdrasilLoginForCell:(UITableViewCell *)cell;

@end

@implementation AccountListViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [AmethystMD3Theme applyToViewController:self];
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.cellLayoutMarginsFollowReadableWidth = YES;

    if (self.accountList == nil) {
        self.accountList = [NSMutableArray array];
    } else {
        [self.accountList removeAllObjects];
    }

    // List accounts
    NSString *listPath = [NSString stringWithFormat:@"%s/accounts", getenv("POJAV_HOME")];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:listPath error:nil];
    for(NSString *file in files) {
        NSString *path = [listPath stringByAppendingPathComponent:file];
        BOOL isDir = NO;
        [fm fileExistsAtPath:path isDirectory:(&isDir)];
        if(!isDir && [file hasSuffix:@".json"]) {
            [self.accountList addObject:parseJSONFromFile(path)];
        }
    }

    [AmethystMD3Theme styleTableView:self.tableView];
    self.tableView.contentInset = UIEdgeInsetsMake(8.0, 0.0, 20.0, 0.0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(8.0, 0.0, 20.0, 0.0);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.accountList.count + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    }

    if (indexPath.row == self.accountList.count) {
        cell.imageView.image = [UIImage imageNamed:@"IconAdd"];
        cell.textLabel.text = localize(@"login.option.add", nil);
        [AmethystMD3Theme styleCell:cell inTableView:tableView];
        cell.textLabel.textColor = AmethystMD3Theme.primaryColor;
        return cell;
    }

    NSDictionary *selected = self.accountList[indexPath.row];
    // By default, display the saved username
    cell.textLabel.text = selected[@"username"];
    if ([selected[@"username"] hasPrefix:@"Demo."]) {
        // Remove the prefix "Demo."
        cell.textLabel.text = [selected[@"username"] substringFromIndex:5];
        cell.detailTextLabel.text = localize(@"login.option.demo", nil);
    } else if ([selected[@"accountType"] isEqual:@"yggdrasil"]) {
        cell.detailTextLabel.text = selected[@"serverName"] ?: localize(@"login.option.yggdrasil", nil);
    } else if (selected[@"xboxGamertag"] == nil) {
        cell.detailTextLabel.text = localize(@"login.option.local", nil);
    } else {
        // Display the Xbox gamertag for online accounts
        cell.detailTextLabel.text = selected[@"xboxGamertag"];
    }

    cell.imageView.contentMode = UIViewContentModeCenter;
    [cell.imageView setImageWithURL:[NSURL URLWithString:[selected[@"profilePicURL"] stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"]] placeholderImage:[UIImage imageNamed:@"DefaultAccount"]];
    [AmethystMD3Theme styleCell:cell inTableView:tableView];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];

    if (indexPath.row == self.accountList.count) {
        [self actionAddAccount:cell];
        return;
    }

    self.modalInPresentation = YES;
    self.tableView.userInteractionEnabled = NO;
    [self addActivityIndicatorTo:cell];

    id callback = ^(id status, BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^(){
            [self callbackMicrosoftAuth:status success:success forCell:cell];
        });
    };
    [[BaseAuthenticator loadSavedName:self.accountList[indexPath.row][@"username"]] refreshTokenWithCallback:callback];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // TODO: invalidate token

        NSString *str = self.accountList[indexPath.row][@"username"];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *path = [NSString stringWithFormat:@"%s/accounts/%@.json", getenv("POJAV_HOME"), str];
        if (self.whenDelete != nil) {
            self.whenDelete(str);
        }
        NSString *xuid = self.accountList[indexPath.row][@"xuid"];
        if (xuid) {
            [MicrosoftAuthenticator clearTokenDataOfProfile:xuid];
        }
        [fm removeItemAtPath:path error:nil];
        [self.accountList removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == self.accountList.count) {
        return UITableViewCellEditingStyleNone;
    } else {
        return UITableViewCellEditingStyleDelete;
    }
}

- (NSDictionary *)parseQueryItems:(NSString *)url {
    NSMutableDictionary *result = [NSMutableDictionary new];
    NSArray<NSURLQueryItem *> *queryItems = [NSURLComponents componentsWithString:url].queryItems;
    for (NSURLQueryItem *item in queryItems) {
        result[item.name] = item.value;
    }
    return result;
}

- (void)actionAddAccount:(UITableViewCell *)sender {
    UIAlertController *picker = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *actionMicrosoft = [UIAlertAction actionWithTitle:localize(@"login.option.microsoft", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self actionLoginMicrosoft:sender];
    }];
    [picker addAction:actionMicrosoft];
    UIAlertAction *actionYggdrasil = [UIAlertAction actionWithTitle:localize(@"login.option.yggdrasil", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self actionLoginYggdrasil:sender];
    }];
    [picker addAction:actionYggdrasil];
    UIAlertAction *actionLocal = [UIAlertAction actionWithTitle:localize(@"login.option.local", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self actionLoginLocal:sender];
    }];
    [picker addAction:actionLocal];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil];
    [picker addAction:cancel];

    picker.popoverPresentationController.sourceView = sender;
    picker.popoverPresentationController.sourceRect = sender.bounds;

    [self presentViewController:picker animated:YES completion:nil];
}

- (void)actionLoginLocal:(UIView *)sender {
    if (getPrefBool(@"warnings.local_warn")) {
        setPrefBool(@"warnings.local_warn", NO);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"login.warn.title.localmode", nil) message:localize(@"login.warn.message.localmode", nil) preferredStyle:UIAlertControllerStyleActionSheet];
        alert.popoverPresentationController.sourceView = sender;
        alert.popoverPresentationController.sourceRect = sender.bounds;
        UIAlertAction *ok = [UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {[self actionLoginLocal:sender];}];
        [alert addAction:ok];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:localize(@"Sign in", nil) message:localize(@"login.option.local", nil) preferredStyle:UIAlertControllerStyleAlert];
    [controller addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = localize(@"login.alert.field.username", nil);
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleRoundedRect;
    }];
    [controller addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSArray *textFields = controller.textFields;
        UITextField *usernameField = textFields[0];
        if (usernameField.text.length < 3 || usernameField.text.length > 16) {
            controller.message = localize(@"login.error.username.outOfRange", nil);
            [self presentViewController:controller animated:YES completion:nil];
        } else {
            id callback = ^(id status, BOOL success) {
                self.whenItemSelected();
                [self dismissViewControllerAnimated:YES completion:nil];
            };
            [[[LocalAuthenticator alloc] initWithInput:usernameField.text] loginWithCallback:callback];
        }
    }]];
    [controller addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:controller animated:YES completion:nil];
}


- (void)actionLoginYggdrasil:(UITableViewCell *)sender {
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:localize(@"login.yggdrasil.title", nil)
        message:localize(@"login.yggdrasil.message", nil)
        preferredStyle:UIAlertControllerStyleAlert];

    [controller addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = localize(@"login.yggdrasil.api", nil);
        textField.text = @"https://skin.example.com/api/yggdrasil";
        textField.keyboardType = UIKeyboardTypeURL;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleRoundedRect;
    }];
    [controller addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = localize(@"login.yggdrasil.username", nil);
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleRoundedRect;
    }];
    [controller addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = localize(@"login.yggdrasil.password", nil);
        textField.secureTextEntry = YES;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.borderStyle = UITextBorderStyleRoundedRect;
    }];
    [controller addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = localize(@"login.yggdrasil.authlib", nil);
        const char *pojavHome = getenv("POJAV_HOME");
        textField.text = pojavHome == NULL ? @"" : [NSString stringWithFormat:@"%s/authlib-injector.jar", pojavHome];
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleRoundedRect;
    }];

    [controller addAction:[UIAlertAction actionWithTitle:localize(@"login.yggdrasil.login", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *rawAPI = controller.textFields[0].text;
        NSString *username = [controller.textFields[1].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *password = controller.textFields[2].text;
        NSString *authlibPath = [controller.textFields[3].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSError *apiError = nil;
        NSString *apiRoot = [YggdrasilAuthenticator normalizedAPIRoot:rawAPI error:&apiError];
        if (apiRoot == nil || username.length == 0 || password.length == 0 || authlibPath.length == 0) {
            controller.message = apiRoot == nil ? apiError.localizedDescription : localize(@"login.yggdrasil.error.incomplete", nil);
            [self presentViewController:controller animated:YES completion:nil];
            return;
        }

        // The password is copied into the authenticator's private in-memory
        // property and is never placed in authData or written to disk.
        YggdrasilAuthenticator *authenticator = [[YggdrasilAuthenticator alloc]
            initWithAPIRoot:apiRoot
                     username:username
                     password:password
         authlibInjectorPath:authlibPath];
        controller.textFields[2].text = @"";
        self.modalInPresentation = YES;
        self.tableView.userInteractionEnabled = NO;
        [self addActivityIndicatorTo:sender];
        [authenticator loginWithCallback:^(id status, BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self handleYggdrasilStatus:status success:success forCell:sender authenticator:authenticator];
            });
        }];
    }]];
    [controller addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)handleYggdrasilStatus:(id)status
                      success:(BOOL)success
                       forCell:(UITableViewCell *)cell
                 authenticator:(YggdrasilAuthenticator *)authenticator {
    if (!success) {
        [self cancelYggdrasilLoginForCell:cell];
        NSString *message = [status isKindOfClass:NSError.class] ? [status localizedDescription] : [status description];
        showDialog(localize(@"Error", nil), message ?: localize(@"login.yggdrasil.error.unknown", nil));
        return;
    }
    if ([status isKindOfClass:NSArray.class]) {
        [self presentYggdrasilProfilePicker:status authenticator:authenticator forCell:cell];
    } else if ([status isKindOfClass:NSString.class]) {
        cell.detailTextLabel.text = status;
    } else if (status == nil) {
        [self finishYggdrasilLoginForCell:cell];
    }
}

- (void)presentYggdrasilProfilePicker:(NSArray *)profiles
                        authenticator:(YggdrasilAuthenticator *)authenticator
                               forCell:(UITableViewCell *)cell {
    UIAlertController *picker = [UIAlertController alertControllerWithTitle:localize(@"login.yggdrasil.select", nil)
        message:localize(@"login.yggdrasil.select.message", nil)
        preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *profile in profiles) {
        NSString *title = [NSString stringWithFormat:@"%@\n%@", profile[@"name"], profile[@"profileId"] ?: profile[@"id"]];
        [picker addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [authenticator selectProfile:profile callback:^(id status, BOOL success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self handleYggdrasilStatus:status success:success forCell:cell authenticator:authenticator];
                });
            }];
        }]];
    }
    [picker addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self cancelYggdrasilLoginForCell:cell];
    }]];
    picker.popoverPresentationController.sourceView = cell;
    picker.popoverPresentationController.sourceRect = cell.bounds;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)finishYggdrasilLoginForCell:(UITableViewCell *)cell {
    self.modalInPresentation = NO;
    self.tableView.userInteractionEnabled = YES;
    [self removeActivityIndicatorFrom:cell];
    if (self.whenItemSelected) self.whenItemSelected();
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)cancelYggdrasilLoginForCell:(UITableViewCell *)cell {
    self.modalInPresentation = NO;
    self.tableView.userInteractionEnabled = YES;
    [self removeActivityIndicatorFrom:cell];
}


- (void)actionLoginMicrosoft:(UITableViewCell *)sender {
    NSURL *url = [NSURL URLWithString:@"https://login.live.com/oauth20_authorize.srf?client_id=00000000402b5328&response_type=code&scope=service%3A%3Auser.auth.xboxlive.com%3A%3AMBI_SSL&redirect_url=https%3A%2F%2Flogin.live.com%2Foauth20_desktop.srf"];

    self.authVC =
        [[ASWebAuthenticationSession alloc] initWithURL:url
        callbackURLScheme:@"ms-xal-00000000402b5328"
        completionHandler:^(NSURL * _Nullable callbackURL, NSError * _Nullable error)
    {
        if (callbackURL == nil) {
            if (error.code != ASWebAuthenticationSessionErrorCodeCanceledLogin) {
                showDialog(localize(@"Error", nil), error.localizedDescription);
            }
            return;
        }
        // NSLog(@"URL returned = %@", [callbackURL absoluteString]);

        NSDictionary *queryItems = [self parseQueryItems:callbackURL.absoluteString];
        if (queryItems[@"code"]) {
            dispatch_async(dispatch_get_main_queue(), ^(){
                self.modalInPresentation = YES;
                self.tableView.userInteractionEnabled = NO;
                [self addActivityIndicatorTo:sender];
            });
            id callback = ^(id status, BOOL success) {
                if ([status isKindOfClass:NSString.class] && [status isEqualToString:@"DEMO"] && success) {
                    showDialog(localize(@"login.warn.title.demomode", nil), localize(@"login.warn.message.demomode", nil));
                }
                dispatch_async(dispatch_get_main_queue(), ^(){
                    [self callbackMicrosoftAuth:status success:success forCell:sender];
                });
            };
            [[[MicrosoftAuthenticator alloc] initWithInput:queryItems[@"code"]] loginWithCallback:callback];
        } else {
            if ([queryItems[@"error"] hasPrefix:@"access_denied"]) {
                // Ignore access denial responses
                return;
            }
            showDialog(localize(@"Error", nil), queryItems[@"error_description"]);
        }
    }];

    self.authVC.prefersEphemeralWebBrowserSession = YES;
    self.authVC.presentationContextProvider = self;

    if ([self.authVC start] == NO) {
        showDialog(localize(@"Error", nil), @"Unable to open Safari");
    }
}

- (void)addActivityIndicatorTo:(UITableViewCell *)cell {
    UIActivityIndicatorViewStyle indicatorStyle = UIActivityIndicatorViewStyleMedium;
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:indicatorStyle];
    cell.accessoryView = indicator;
    [indicator sizeToFit];
    [indicator startAnimating];
}

- (void)removeActivityIndicatorFrom:(UITableViewCell *)cell {
    UIActivityIndicatorView *indicator = (id)cell.accessoryView;
    [indicator stopAnimating];
    cell.accessoryView = nil;
}

- (void)callbackMicrosoftAuth:(id)status success:(BOOL)success forCell:(UITableViewCell *)cell {
    if (status != nil) {
        if (success) {
            cell.detailTextLabel.text = status;
        } else {
            self.modalInPresentation = NO;
            self.tableView.userInteractionEnabled = YES;
            [self removeActivityIndicatorFrom:cell];
            cell.detailTextLabel.text = [status localizedDescription];
            NSData *errorData = ((NSError *)status).userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
            NSString *errorStr = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
            NSLog(@"[MSA] Error: %@", errorStr);
            showDialog(localize(@"Error", nil), errorStr);
        }
    } else if (success) {
        self.whenItemSelected();
        [self removeActivityIndicatorFrom:cell];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - UIPopoverPresentationControllerDelegate
- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller traitCollection:(UITraitCollection *)traitCollection {
    return UIModalPresentationNone;
}

#pragma mark - ASWebAuthenticationPresentationContextProviding
- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)session {
    return UIApplication.sharedApplication.windows.firstObject;
}

@end
