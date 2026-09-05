#import "LauncherMenuViewController.h"
#import "AmethystMD3Theme.h"
#import "authenticator/BaseAuthenticator.h"
#import "LauncherNavigationController.h"
#import "LauncherPreferences.h"
#import "LauncherPrefGameDirViewController.h"
#import "LauncherPrefManageJREViewController.h"
#import "LauncherProfileEditorViewController.h"
#import "LauncherProfilesViewController.h"
#import "PLProfiles.h"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#import "UIKit+AFNetworking.h"
#pragma clang diagnostic pop
#import "UIKit+hook.h"
#import "installer/FabricInstallViewController.h"
#import "installer/ForgeInstallViewController.h"
#import "installer/ModpackInstallViewController.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

typedef NS_ENUM(NSUInteger, LauncherProfilesTableSection) {
    kInstances,
    kProfiles
};

@interface LauncherProfilesViewController ()
@property(nonatomic) UIBarButtonItem *createButtonItem;
@property(nonatomic) UIView *dashboardHeaderView;
@property(nonatomic) UIImageView *accountImageView;
@property(nonatomic) UILabel *accountNameLabel;
@property(nonatomic) UILabel *accountDetailLabel;
@property(nonatomic) UILabel *dashboardHintLabel;
@end

@implementation LauncherProfilesViewController

- (id)init {
    self = [super init];
    self.title = localize(@"Profiles", nil);
    return self;
}

- (NSString *)imageName {
    return @"MenuProfiles";
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.cellLayoutMarginsFollowReadableWidth = YES;
    [AmethystMD3Theme styleTableView:self.tableView];

    UIMenu *createMenu = [UIMenu menuWithTitle:localize(@"profile.title.create", nil)
        image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[
        [UIAction actionWithTitle:@"Vanilla" image:nil identifier:@"vanilla" handler:^(UIAction *action) {
            [self actionEditProfile:@{@"name": @"", @"lastVersionId": @"latest-release"}];
        }],
        [UIAction actionWithTitle:@"Fabric/Quilt" image:nil identifier:@"fabric_or_quilt" handler:^(UIAction *action) {
            [self actionCreateFabricProfile];
        }],
        [UIAction actionWithTitle:@"Forge" image:nil identifier:@"forge" handler:^(UIAction *action) {
            [self actionCreateForgeProfile];
        }],
        [UIAction actionWithTitle:@"Modpack" image:nil identifier:@"modpack" handler:^(UIAction *action) {
            [self actionCreateModpackProfile];
        }]
    ]];
    self.createButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd menu:createMenu];
    if (@available(iOS 19.0, *)) {
        [self.createButtonItem setValue:@NO forKey:@"sharesBackground"];
    }

    self.dashboardHeaderView = [self makeDashboardHeaderView];
    self.tableView.tableHeaderView = self.dashboardHeaderView;
    [self updateDashboardHeader];
}

- (UIView *)makeDashboardHeaderView {
    UIView *header = [UIView new];
    header.backgroundColor = UIColor.clearColor;

    UIView *content = [UIView new];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:content];

    UIView *heroCard = [UIView new];
    heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    [AmethystMD3Theme styleCard:heroCard];
    [content addSubview:heroCard];

    UILabel *heroTitle = [UILabel new];
    heroTitle.translatesAutoresizingMaskIntoConstraints = NO;
    heroTitle.text = @"Play Minecraft Java";
    heroTitle.textColor = AmethystMD3Theme.onSurfaceColor;
    heroTitle.font = [UIFont systemFontOfSize:26.0 weight:UIFontWeightBold];
    heroTitle.adjustsFontForContentSizeCategory = YES;

    UILabel *heroSubtitle = [UILabel new];
    heroSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    heroSubtitle.text = @"Instances, profiles, and launch settings";
    heroSubtitle.textColor = AmethystMD3Theme.onSurfaceVariantColor;
    heroSubtitle.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular];
    heroSubtitle.numberOfLines = 0;
    heroSubtitle.adjustsFontForContentSizeCategory = YES;

    UIButton *launchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    launchButton.translatesAutoresizingMaskIntoConstraints = NO;
    [launchButton setTitle:localize(@"Play", nil) forState:UIControlStateNormal];
    [launchButton setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
    launchButton.imageEdgeInsets = UIEdgeInsetsMake(0.0, -6.0, 0.0, 6.0);
    [AmethystMD3Theme styleFilledButton:launchButton];
    [launchButton addTarget:self.navigationController action:@selector(performInstallOrShowDetails:)
        forControlEvents:UIControlEventPrimaryActionTriggered];
    [heroCard addSubview:heroTitle];
    [heroCard addSubview:heroSubtitle];
    [heroCard addSubview:launchButton];

    UIView *accountCard = [UIView new];
    accountCard.translatesAutoresizingMaskIntoConstraints = NO;
    [AmethystMD3Theme styleOutlinedCard:accountCard];
    [content addSubview:accountCard];

    self.accountImageView = [UIImageView new];
    self.accountImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.accountImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.accountImageView.clipsToBounds = YES;
    self.accountImageView.layer.cornerRadius = 24.0;
    self.accountImageView.layer.cornerCurve = kCACornerCurveContinuous;
    [accountCard addSubview:self.accountImageView];

    self.accountNameLabel = [UILabel new];
    self.accountNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.accountNameLabel.textColor = AmethystMD3Theme.onSurfaceColor;
    self.accountNameLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    self.accountNameLabel.adjustsFontForContentSizeCategory = YES;

    self.accountDetailLabel = [UILabel new];
    self.accountDetailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.accountDetailLabel.textColor = AmethystMD3Theme.onSurfaceVariantColor;
    self.accountDetailLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
    self.accountDetailLabel.numberOfLines = 0;
    self.accountDetailLabel.adjustsFontForContentSizeCategory = YES;

    UIStackView *accountCopy = [[UIStackView alloc] initWithArrangedSubviews:@[self.accountNameLabel, self.accountDetailLabel]];
    accountCopy.translatesAutoresizingMaskIntoConstraints = NO;
    accountCopy.axis = UILayoutConstraintAxisVertical;
    accountCopy.alignment = UIStackViewAlignmentLeading;
    accountCopy.spacing = 3.0;
    [accountCard addSubview:accountCopy];

    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.tintColor = AmethystMD3Theme.onSurfaceVariantColor;
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    [accountCard addSubview:chevron];

    self.dashboardHintLabel = [UILabel new];
    self.dashboardHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dashboardHintLabel.textColor = AmethystMD3Theme.onSurfaceVariantColor;
    self.dashboardHintLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular];
    self.dashboardHintLabel.numberOfLines = 0;
    self.dashboardHintLabel.adjustsFontForContentSizeCategory = YES;
    [content addSubview:self.dashboardHintLabel];

    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:header.topAnchor constant:8.0],
        [content.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16.0],
        [content.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16.0],
        [content.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-12.0],

        [heroCard.topAnchor constraintEqualToAnchor:content.topAnchor],
        [heroCard.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [heroCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [heroTitle.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:20.0],
        [heroTitle.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:20.0],
        [heroTitle.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-20.0],
        [heroSubtitle.topAnchor constraintEqualToAnchor:heroTitle.bottomAnchor constant:6.0],
        [heroSubtitle.leadingAnchor constraintEqualToAnchor:heroTitle.leadingAnchor],
        [heroSubtitle.trailingAnchor constraintEqualToAnchor:heroTitle.trailingAnchor],
        [launchButton.topAnchor constraintEqualToAnchor:heroSubtitle.bottomAnchor constant:18.0],
        [launchButton.leadingAnchor constraintEqualToAnchor:heroTitle.leadingAnchor],
        [launchButton.trailingAnchor constraintLessThanOrEqualToAnchor:heroCard.trailingAnchor constant:-20.0],
        [launchButton.heightAnchor constraintGreaterThanOrEqualToConstant:48.0],
        [launchButton.bottomAnchor constraintEqualToAnchor:heroCard.bottomAnchor constant:-20.0],

        [accountCard.topAnchor constraintEqualToAnchor:heroCard.bottomAnchor constant:12.0],
        [accountCard.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [accountCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [accountCard.heightAnchor constraintGreaterThanOrEqualToConstant:82.0],
        [self.accountImageView.leadingAnchor constraintEqualToAnchor:accountCard.leadingAnchor constant:16.0],
        [self.accountImageView.centerYAnchor constraintEqualToAnchor:accountCard.centerYAnchor],
        [self.accountImageView.widthAnchor constraintEqualToConstant:48.0],
        [self.accountImageView.heightAnchor constraintEqualToConstant:48.0],
        [accountCopy.leadingAnchor constraintEqualToAnchor:self.accountImageView.trailingAnchor constant:14.0],
        [accountCopy.centerYAnchor constraintEqualToAnchor:accountCard.centerYAnchor],
        [accountCopy.trailingAnchor constraintLessThanOrEqualToAnchor:chevron.leadingAnchor constant:-12.0],
        [chevron.trailingAnchor constraintEqualToAnchor:accountCard.trailingAnchor constant:-18.0],
        [chevron.centerYAnchor constraintEqualToAnchor:accountCard.centerYAnchor],
        [chevron.widthAnchor constraintEqualToConstant:16.0],
        [chevron.heightAnchor constraintEqualToConstant:20.0],

        [self.dashboardHintLabel.topAnchor constraintEqualToAnchor:accountCard.bottomAnchor constant:10.0],
        [self.dashboardHintLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:4.0],
        [self.dashboardHintLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-4.0],
        [self.dashboardHintLabel.bottomAnchor constraintEqualToAnchor:content.bottomAnchor]
    ]];

    return header;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat tableWidth = CGRectGetWidth(self.tableView.bounds);
    if (tableWidth <= 0.0) return;

    CGFloat sideInset = MAX(0.0, (tableWidth - 760.0) / 2.0);
    self.tableView.contentInset = UIEdgeInsetsMake(8.0, sideInset, 20.0, sideInset);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(8.0, sideInset, 20.0, sideInset);

    UIView *header = self.tableView.tableHeaderView;
    CGSize fitting = [header systemLayoutSizeFittingSize:CGSizeMake(tableWidth, UILayoutFittingCompressedSize.height)
        withHorizontalFittingPriority:UILayoutPriorityRequired
        verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    CGFloat height = MAX(260.0, fitting.height);
    if (fabs(header.frame.size.width - tableWidth) > 0.5 || fabs(header.frame.size.height - height) > 0.5) {
        header.frame = CGRectMake(0.0, 0.0, tableWidth, height);
        self.tableView.tableHeaderView = header;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [AmethystMD3Theme applyToViewController:self];
    self.navigationItem.rightBarButtonItems = @[[sidebarViewController drawAccountButton], self.createButtonItem];
    [PLProfiles updateCurrent];
    [self updateDashboardHeader];
    [self.tableView reloadData];
    [self.navigationController performSelector:@selector(reloadProfileList)];
}

- (void)updateDashboardHeader {
    if (!self.accountNameLabel) return;

    NSDictionary *selected = BaseAuthenticator.current.authData;
    UIImage *placeholder = [UIImage imageNamed:@"DefaultAccount"];
    if (!selected) {
        self.accountNameLabel.text = localize(@"login.option.select", nil);
        self.accountDetailLabel.text = localize(@"login.option.local", nil);
        self.dashboardHintLabel.text = @"Choose an account, then choose an instance from the bottom bar.";
        self.accountImageView.image = placeholder;
        return;
    }

    NSString *username = selected[@"username"] ?: @"Minecraft account";
    self.accountNameLabel.text = [username hasPrefix:@"Demo."] ? [username substringFromIndex:5] : username;
    if ([selected[@"accountType"] isEqual:@"yggdrasil"]) {
        self.accountDetailLabel.text = selected[@"serverName"] ?: localize(@"login.option.yggdrasil", nil);
    } else if (selected[@"xboxGamertag"]) {
        self.accountDetailLabel.text = selected[@"xboxGamertag"];
    } else {
        self.accountDetailLabel.text = localize(@"login.option.local", nil);
    }
    self.dashboardHintLabel.text = @"The selected profile is used by the launcher when the game starts.";

    NSString *profilePicURL = [selected[@"profilePicURL"] stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
    [self.accountImageView setImageWithURL:[NSURL URLWithString:profilePicURL] placeholderImage:placeholder];
}

- (void)actionTogglePrefIsolation:(UISwitch *)sender {
    if (!sender.isOn) setPrefBool(@"internal.isolated", NO);
    toggleIsolatedPref(sender.isOn);
}

- (void)actionCreateFabricProfile {
    [self presentNavigatedViewController:[FabricInstallViewController new]];
}

- (void)actionCreateForgeProfile {
    [self presentNavigatedViewController:[ForgeInstallViewController new]];
}

- (void)actionCreateModpackProfile {
    [self presentNavigatedViewController:[ModpackInstallViewController new]];
}

- (void)actionEditProfile:(NSDictionary *)profile {
    LauncherProfileEditorViewController *vc = [LauncherProfileEditorViewController new];
    vc.profile = profile.mutableCopy;
    [self presentNavigatedViewController:vc];
}

- (void)presentNavigatedViewController:(UIViewController *)vc {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *container = [UIView new];
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = section == kInstances
        ? localize(@"profile.section.instance", nil)
        : localize(@"profile.section.profiles", nil);
    [AmethystMD3Theme styleSectionHeaderLabel:label];
    [container addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:4.0],
        [label.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-4.0],
        [label.topAnchor constraintEqualToAnchor:container.topAnchor constant:6.0],
        [label.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-4.0]
    ]];
    return container;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 42.0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == kInstances ? 2 : PLProfiles.current.profiles.count;
}

- (void)setupInstanceCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    cell.userInteractionEnabled = !getenv("DEMO_LOCK");
    if (row == 0) {
        cell.imageView.image = [UIImage systemImageNamed:@"folder"];
        cell.textLabel.text = localize(@"preference.title.game_directory", nil);
        cell.detailTextLabel.text = getenv("DEMO_LOCK") ? @".demo" : getPrefObject(@"general.game_directory");
    } else {
        cell.imageView.image = [UIImage systemImageNamed:@"folder.badge.gearshape"] ?: [UIImage systemImageNamed:@"folder.badge.gear"];
        cell.textLabel.text = localize(@"profile.title.separate_preference", nil);
        cell.detailTextLabel.text = localize(@"profile.detail.separate_preference", nil);
        UISwitch *toggle = [UISwitch new];
        [toggle setOn:getPrefBool(@"internal.isolated") animated:NO];
        [toggle addTarget:self action:@selector(actionTogglePrefIsolation:) forControlEvents:UIControlEventValueChanged];
        toggle.onTintColor = AmethystMD3Theme.primaryColor;
        cell.accessoryView = toggle;
    }
}

- (void)setupProfileCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    NSMutableDictionary *profile = PLProfiles.current.profiles.allValues[row];
    cell.textLabel.text = profile[@"name"];
    cell.detailTextLabel.text = profile[@"lastVersionId"];
    cell.imageView.layer.magnificationFilter = kCAFilterNearest;
    UIImage *fallback = [[UIImage imageNamed:@"DefaultProfile"] _imageWithSize:CGSizeMake(48.0, 48.0)];
    [cell.imageView setImageWithURL:[NSURL URLWithString:profile[@"icon"]] placeholderImage:fallback];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellID = indexPath.section == kInstances ? @"launcher.instance.cell" : @"launcher.profile.cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
        cell.imageView.isSizeFixed = YES;
    }

    cell.imageView.image = nil;
    cell.accessoryView = nil;
    cell.userInteractionEnabled = YES;
    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;
    if (indexPath.section == kInstances) {
        [self setupInstanceCell:cell atRow:indexPath.row];
    } else {
        [self setupProfileCell:cell atRow:indexPath.row];
    }
    cell.textLabel.enabled = cell.detailTextLabel.enabled = cell.userInteractionEnabled;
    [AmethystMD3Theme styleCell:cell inTableView:tableView];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == kInstances) {
        if (indexPath.row == 0) {
            [self.navigationController pushViewController:[LauncherPrefGameDirViewController new] animated:YES];
        }
        return;
    }
    [self actionEditProfile:PLProfiles.current.profiles.allValues[indexPath.row]];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;

    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSString *title = localize(@"preference.title.confirm", nil);
    NSString *message = [NSString stringWithFormat:localize(@"preference.title.confirm.delete_runtime", nil), cell.textLabel.text];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message
        preferredStyle:UIAlertControllerStyleActionSheet];
    alert.popoverPresentationController.sourceView = cell;
    alert.popoverPresentationController.sourceRect = cell.bounds;
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [PLProfiles.current.profiles removeObjectForKey:cell.textLabel.text];
        if ([PLProfiles.current.selectedProfileName isEqualToString:cell.textLabel.text]) {
            PLProfiles.current.selectedProfileName = PLProfiles.current.profiles.allKeys.firstObject;
            [self.navigationController performSelector:@selector(reloadProfileList)];
        } else {
            [PLProfiles.current save];
        }
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == kInstances || PLProfiles.current.profiles.count == 1) {
        return UITableViewCellEditingStyleNone;
    }
    return UITableViewCellEditingStyleDelete;
}

@end
