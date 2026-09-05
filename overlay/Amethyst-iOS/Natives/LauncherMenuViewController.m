#import "authenticator/BaseAuthenticator.h"
#import "AccountListViewController.h"
#import "AFNetworking.h"
#import "AmethystMD3Theme.h"
#import "ALTServerConnection.h"
#import "LauncherNavigationController.h"
#import "LauncherMenuViewController.h"
#import "LauncherNewsViewController.h"
#import "LauncherPreferences.h"
#import "LauncherPreferencesViewController.h"
#import "LauncherProfilesViewController.h"
#import "PLProfiles.h"
#import "UIButton+AFNetworking.h"
#import "UIImageView+AFNetworking.h"
#import "UIKit+hook.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

#include <dlfcn.h>

@implementation LauncherMenuCustomItem

+ (LauncherMenuCustomItem *)title:(NSString *)title imageName:(NSString *)imageName action:(id)action {
    LauncherMenuCustomItem *item = [[LauncherMenuCustomItem alloc] init];
    item.title = title;
    item.imageName = imageName;
    item.action = action;
    return item;
}

+ (LauncherMenuCustomItem *)vcClass:(Class)class {
    id vc = [class new];
    LauncherMenuCustomItem *item = [[LauncherMenuCustomItem alloc] init];
    item.title = [vc title];
    item.imageName = [vc imageName];
    // View controllers are put into an array to keep their state.
    item.vcArray = @[vc];
    return item;
}

@end

@interface LauncherMenuViewController ()
@property(nonatomic) NSMutableArray<LauncherMenuCustomItem *> *options;
@property(nonatomic) int lastSelectedIndex;
@property(nonatomic) UIView *brandHeaderView;
@end

@implementation LauncherMenuViewController

#define contentNavigationController ((LauncherNavigationController *)self.splitViewController.viewControllers[1])

- (void)viewDidLoad {
    [super viewDidLoad];

    self.isInitialVc = YES;
    self.title = @"Amethyst";
    self.navigationController.navigationBar.prefersLargeTitles = NO;

    // InsetGrouped supplies the drawer-like surface on both iPhone and iPad;
    // the table itself remains fully self-sizing and readable-width aware.
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [AmethystMD3Theme styleTableView:self.tableView];
    self.tableView.contentInset = UIEdgeInsetsMake(4.0, 0.0, 20.0, 0.0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(4.0, 0.0, 20.0, 0.0);

    self.brandHeaderView = [self makeBrandHeaderView];
    self.tableView.tableHeaderView = self.brandHeaderView;

    self.options = @[
        [LauncherMenuCustomItem vcClass:LauncherNewsViewController.class],
        [LauncherMenuCustomItem vcClass:LauncherProfilesViewController.class],
        [LauncherMenuCustomItem vcClass:LauncherPreferencesViewController.class],
    ].mutableCopy;

    if (realUIIdiom != UIUserInterfaceIdiomTV) {
        [self.options addObject:(id)[LauncherMenuCustomItem
            title:localize(@"launcher.menu.custom_controls", nil)
            imageName:@"MenuCustomControls" action:^{
                [contentNavigationController performSelector:@selector(enterCustomControls)];
            }]];
    }

    [self.options addObject:(id)[LauncherMenuCustomItem
        title:localize(@"launcher.menu.execute_jar", nil)
        imageName:@"MenuInstallJar" action:^{
            [contentNavigationController performSelector:@selector(enterModInstaller)];
        }]];

    [self.options addObject:(id)[LauncherMenuCustomItem
        title:localize(@"login.menu.sendlogs", nil)
        imageName:@"square.and.arrow.up" action:^{
            NSString *latestlogPath = [NSString stringWithFormat:@"file://%s/latestlog.old.txt", getenv("POJAV_HOME")];
            UIActivityViewController *activityVC;
            if (realUIIdiom != UIUserInterfaceIdiomTV) {
                activityVC = [[UIActivityViewController alloc]
                    initWithActivityItems:@[[NSURL URLWithString:latestlogPath]]
                    applicationActivities:nil];
            } else {
                dlopen("/System/Library/PrivateFrameworks/SharingUI.framework/SharingUI", RTLD_GLOBAL);
                activityVC = [[NSClassFromString(@"SFAirDropSharingViewControllerTV")
                    alloc] performSelector:@selector(initWithSharingItems:)
                    withObject:@[[NSURL URLWithString:latestlogPath]]];
            }
            activityVC.popoverPresentationController.sourceView = self.view;
            activityVC.popoverPresentationController.sourceRect = self.view.bounds;
            [self presentViewController:activityVC animated:YES completion:nil];
        }]];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"MM-dd";
    NSString *date = [dateFormatter stringFromDate:NSDate.date];
    if ([date isEqualToString:@"06-29"] || [date isEqualToString:@"06-30"] || [date isEqualToString:@"07-01"]) {
        [self.options addObject:(id)[LauncherMenuCustomItem
            title:@"Technoblade never dies!" imageName:@"" action:^{
                openLink(self, [NSURL URLWithString:@"https://youtu.be/DPMluEVUqS0"]);
            }]];
    }

    self.navigationController.toolbarHidden = NO;
    UIActivityIndicatorView *toolbarIndicator =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    [toolbarIndicator startAnimating];
    self.toolbarItems = @[
        [[UIBarButtonItem alloc] initWithCustomView:toolbarIndicator],
        [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil]
    ];

    self.accountBtnItem = [self drawAccountButton];
    self.navigationItem.rightBarButtonItem = self.accountBtnItem;
    [self updateAccountInfo];

    if (self.options.count > 1) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:1 inSection:0];
        [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
        self.lastSelectedIndex = 1;
    }

    if (getEntitlementValue(@"get-task-allow")) {
        [self displayProgress:localize(@"login.jit.checking", nil)];
        if (isJITEnabled(false)) {
            [self displayProgress:localize(@"login.jit.enabled", nil)];
            [self displayProgress:nil];
        } else if (@available(iOS 17.0, *)) {
            // Enabling JIT for 17.0+ is done when we actually launch the game.
        } else {
            [self enableJITWithAltKit];
        }
    } else if (!NSProcessInfo.processInfo.macCatalystApp && !getenv("SIMULATOR_DEVICE_NAME")) {
        [self displayProgress:localize(@"login.jit.fail", nil)];
        [self displayProgress:nil];
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:localize(@"login.jit.fail.title", nil)
            message:localize(@"login.jit.fail.description_unsupported", nil)
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil)
            style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                exit(-1);
            }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (UIView *)makeBrandHeaderView {
    UIView *header = [UIView new];
    header.backgroundColor = UIColor.clearColor;

    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [AmethystMD3Theme styleCard:card];
    [header addSubview:card];

    UIImageView *logo = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AppLogo"]];
    logo.translatesAutoresizingMaskIntoConstraints = NO;
    logo.contentMode = UIViewContentModeScaleAspectFit;
    logo.backgroundColor = AmethystMD3Theme.surfaceContainerLowestColor;
    logo.layer.cornerRadius = 18.0;
    logo.layer.cornerCurve = kCACornerCurveContinuous;
    logo.clipsToBounds = YES;
    [card addSubview:logo];

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Minecraft Java";
    title.textColor = AmethystMD3Theme.onSurfaceColor;
    title.font = [UIFont systemFontOfSize:21.0 weight:UIFontWeightBold];
    title.adjustsFontForContentSizeCategory = YES;

    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"Amethyst launcher";
    subtitle.textColor = AmethystMD3Theme.onSurfaceVariantColor;
    subtitle.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    subtitle.adjustsFontForContentSizeCategory = YES;

    UIStackView *copy = [[UIStackView alloc] initWithArrangedSubviews:@[title, subtitle]];
    copy.translatesAutoresizingMaskIntoConstraints = NO;
    copy.axis = UILayoutConstraintAxisVertical;
    copy.alignment = UIStackViewAlignmentLeading;
    copy.spacing = 4.0;
    [card addSubview:copy];

    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor constraintEqualToAnchor:header.topAnchor constant:8.0],
        [card.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16.0],
        [card.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16.0],
        [card.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-8.0],
        [logo.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [logo.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [logo.widthAnchor constraintEqualToConstant:56.0],
        [logo.heightAnchor constraintEqualToConstant:56.0],
        [copy.leadingAnchor constraintEqualToAnchor:logo.trailingAnchor constant:14.0],
        [copy.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [copy.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [card.heightAnchor constraintGreaterThanOrEqualToConstant:88.0]
    ]];
    return header;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIView *header = self.tableView.tableHeaderView;
    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    if (!header || width <= 0.0) return;

    CGSize fitting = [header systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
        withHorizontalFittingPriority:UILayoutPriorityRequired
        verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    CGFloat height = MAX(104.0, fitting.height);
    if (fabs(header.frame.size.width - width) > 0.5 || fabs(header.frame.size.height - height) > 0.5) {
        header.frame = CGRectMake(0.0, 0.0, width, height);
        self.tableView.tableHeaderView = header;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [AmethystMD3Theme applyToViewController:self];
    [self restoreHighlightedSelection];
}

- (UIBarButtonItem *)drawAccountButton {
    if (!self.accountBtnItem) {
        self.accountButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.accountButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.accountButton addTarget:self action:@selector(selectAccount:)
            forControlEvents:UIControlEventPrimaryActionTriggered];
        self.accountButton.accessibilityLabel = @"Minecraft account";
        self.accountButton.accessibilityHint = @"Choose a Minecraft account";
        self.accountButton.imageView.contentMode = UIViewContentModeScaleAspectFill;
        self.accountButton.clipsToBounds = YES;
        self.accountButton.layer.cornerRadius = 18.0;
        self.accountButton.layer.cornerCurve = kCACornerCurveContinuous;
        [self.accountButton.widthAnchor constraintEqualToConstant:40.0].active = YES;
        [self.accountButton.heightAnchor constraintEqualToConstant:40.0].active = YES;
        self.accountBtnItem = [[UIBarButtonItem alloc] initWithCustomView:self.accountButton];
    }

    [self updateAccountInfo];
    return self.accountBtnItem;
}

- (void)restoreHighlightedSelection {
    if (!self.tableView || self.options.count == 0) return;
    NSInteger row = MIN(MAX(self.lastSelectedIndex, 0), (int)self.options.count - 1);
    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]
        animated:NO scrollPosition:UITableViewScrollPositionNone];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.options.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"launcher.menu.cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
            reuseIdentifier:@"launcher.menu.cell"];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.numberOfLines = 1;
    }

    LauncherMenuCustomItem *item = self.options[indexPath.row];
    cell.textLabel.text = item.title;
    cell.imageView.image = nil;
    NSString *imageName = item.imageName;
    UIImage *image = imageName.length ? [UIImage systemImageNamed:imageName] : nil;
    if (!image && imageName.length) image = [UIImage imageNamed:imageName];
    cell.imageView.image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    cell.imageView.tintColor = AmethystMD3Theme.primaryColor;
    [AmethystMD3Theme styleCell:cell inTableView:tableView];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    LauncherMenuCustomItem *selected = self.options[indexPath.row];
    if (selected.action) {
        [self restoreHighlightedSelection];
        selected.action();
        return;
    }

    if (self.isInitialVc) {
        self.isInitialVc = NO;
    } else {
        self.options[self.lastSelectedIndex].vcArray = contentNavigationController.viewControllers;
        [contentNavigationController setViewControllers:selected.vcArray animated:NO];
    }
    self.lastSelectedIndex = (int)indexPath.row;
    selected.vcArray[0].navigationItem.rightBarButtonItem = self.accountBtnItem;
    selected.vcArray[0].navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
    selected.vcArray[0].navigationItem.leftItemsSupplementBackButton = YES;
}

- (void)selectAccount:(UIButton *)sender {
    AccountListViewController *vc = [[AccountListViewController alloc] init];
    vc.whenDelete = ^void(NSString *name) {
        if ([name isEqualToString:getPrefObject(@"internal.selected_account")]) {
            BaseAuthenticator.current = nil;
            setPrefObject(@"internal.selected_account", @"");
            [self updateAccountInfo];
        }
    };
    vc.whenItemSelected = ^void() {
        setPrefObject(@"internal.selected_account", BaseAuthenticator.current.authData[@"username"]);
        [self updateAccountInfo];
        if (sender != self.accountButton) {
            [sender sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
        }
    };
    vc.modalPresentationStyle = UIModalPresentationPopover;
    vc.preferredContentSize = CGSizeMake(350.0, 250.0);

    UIPopoverPresentationController *popoverController = vc.popoverPresentationController;
    popoverController.sourceView = sender;
    popoverController.sourceRect = sender.bounds;
    popoverController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    popoverController.delegate = vc;
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)updateAccountInfo {
    NSDictionary *selected = BaseAuthenticator.current.authData;
    if (!selected) {
        [self.accountButton setImage:[UIImage imageNamed:@"DefaultAccount"] forState:UIControlStateNormal];
        self.accountButton.accessibilityValue = localize(@"login.option.select", nil);
        return;
    }

    BOOL isDemo = [selected[@"username"] hasPrefix:@"Demo."];
    BOOL shouldUpdateProfiles = (getenv("DEMO_LOCK") != NULL) != isDemo;
    unsetenv("DEMO_LOCK");
    setenv("POJAV_GAME_DIR", [NSString stringWithFormat:@"%s/Library/Application Support/minecraft", getenv("POJAV_HOME")].UTF8String, 1);

    NSString *subtitle;
    if (isDemo) {
        subtitle = localize(@"login.option.demo", nil);
        setenv("DEMO_LOCK", "1", 1);
        setenv("POJAV_GAME_DIR", [NSString stringWithFormat:@"%s/.demo", getenv("POJAV_HOME")].UTF8String, 1);
    } else if ([selected[@"accountType"] isEqual:@"yggdrasil"]) {
        subtitle = selected[@"serverName"] ?: localize(@"login.option.yggdrasil", nil);
    } else if (selected[@"xboxGamertag"] == nil) {
        subtitle = localize(@"login.option.local", nil);
    } else {
        subtitle = selected[@"xboxGamertag"];
    }

    NSString *username = selected[@"username"] ?: localize(@"login.option.select", nil);
    self.accountButton.accessibilityValue = [NSString stringWithFormat:@"%@, %@", username, subtitle];
    NSURL *url = [NSURL URLWithString:[selected[@"profilePicURL"] stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"]];
    UIImage *placeholder = [UIImage imageNamed:@"DefaultAccount"];
    [self.accountButton setImageForState:UIControlStateNormal withURL:url placeholderImage:placeholder];
    if (!url) [self.accountButton setImage:placeholder forState:UIControlStateNormal];

    if (shouldUpdateProfiles) {
        [contentNavigationController fetchLocalVersionList];
        [contentNavigationController performSelector:@selector(reloadProfileList)];
    }

    UITableViewController *tableVC = contentNavigationController.viewControllers.lastObject;
    if ([tableVC isKindOfClass:UITableViewController.class]) {
        [tableVC.tableView reloadData];
    }
}

- (void)displayProgress:(NSString *)status {
    if (self.toolbarItems.count < 2) return;
    if (!status) {
        [(UIActivityIndicatorView *)self.toolbarItems[0].customView stopAnimating];
    } else {
        self.toolbarItems[1].title = status;
    }
}

- (void)enableJITWithAltKit {
    [ALTServerManager.sharedManager startDiscovering];
    [ALTServerManager.sharedManager autoconnectWithCompletionHandler:^(ALTServerConnection *connection, NSError *error) {
        if (error) {
            NSLog(@"[AltKit] Could not auto-connect to server. %@", error.localizedRecoverySuggestion);
            [self displayProgress:localize(@"login.jit.fail", nil)];
            [self displayProgress:nil];
        }
        [connection enableUnsignedCodeExecutionWithCompletionHandler:^(BOOL success, NSError *error) {
            if (success) {
                NSLog(@"[AltKit] Successfully enabled JIT compilation!");
                [ALTServerManager.sharedManager stopDiscovering];
                [self displayProgress:localize(@"login.jit.enabled", nil)];
                [self displayProgress:nil];
            } else {
                NSLog(@"[AltKit] Error enabling JIT: %@", error.localizedRecoverySuggestion);
                [self displayProgress:localize(@"login.jit.fail", nil)];
                [self displayProgress:nil];
            }
            [connection disconnect];
        }];
    }];
}

@end
