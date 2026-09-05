#import "AmethystMD3Theme.h"
#import <objc/runtime.h>
#include <stdint.h>

static UIColor *AMD3DynamicColor(uint32_t lightHex, uint32_t darkHex) {
    UIColor *(^makeColor)(uint32_t) = ^UIColor *(uint32_t hex) {
        return [UIColor colorWithRed:((hex >> 16) & 0xff) / 255.0
                               green:((hex >> 8) & 0xff) / 255.0
                                blue:(hex & 0xff) / 255.0
                               alpha:1.0];
    };
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
            return makeColor(traits.userInterfaceStyle == UIUserInterfaceStyleDark ? darkHex : lightHex);
        }];
    }
    return makeColor(lightHex);
}

@implementation AmethystMD3Theme

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self applyGlobalAppearance];
    });
}

+ (UIColor *)primaryColor { return AMD3DynamicColor(0x6750A4, 0xD0BCFF); }
+ (UIColor *)onPrimaryColor { return AMD3DynamicColor(0xFFFFFF, 0x381E72); }
+ (UIColor *)primaryContainerColor { return AMD3DynamicColor(0xEADDFF, 0x4F378B); }
+ (UIColor *)onPrimaryContainerColor { return AMD3DynamicColor(0x21005D, 0xEADDFF); }
+ (UIColor *)surfaceColor { return AMD3DynamicColor(0xFFFBFE, 0x141218); }
+ (UIColor *)surfaceContainerColor { return AMD3DynamicColor(0xF3EDF7, 0x211F26); }
+ (UIColor *)surfaceContainerHighColor { return AMD3DynamicColor(0xECE6F0, 0x2B2930); }
+ (UIColor *)onSurfaceColor { return AMD3DynamicColor(0x1D1B20, 0xE6E0E9); }
+ (UIColor *)onSurfaceVariantColor { return AMD3DynamicColor(0x49454F, 0xCAC4D0); }
+ (UIColor *)outlineColor { return AMD3DynamicColor(0x79747E, 0x938F99); }

+ (void)applyGlobalAppearance {
    UIColor *primary = self.primaryColor;
    UIColor *surface = self.surfaceColor;
    UIColor *onSurface = self.onSurfaceColor;

    // Scope appearance proxies to launcher screens, not system authentication,
    // document pickers, or the Minecraft/control-editor view hierarchy.
    for (NSString *name in @[@"LauncherMenuViewController", @"LauncherNavigationController",
                            @"PLPrefTableViewController", @"LauncherProfilesViewController",
                            @"AccountListViewController", @"DownloadProgressViewController"]) {
        Class container = NSClassFromString(name);
        if (!container) continue;
        NSArray *containers = @[container];
        [UISwitch appearanceWhenContainedInInstancesOfClasses:containers].onTintColor = primary;
        [UISlider appearanceWhenContainedInInstancesOfClasses:containers].minimumTrackTintColor = primary;
        [UIProgressView appearanceWhenContainedInInstancesOfClasses:containers].progressTintColor = primary;
        [UIProgressView appearanceWhenContainedInInstancesOfClasses:containers].trackTintColor = self.surfaceContainerHighColor;
    }

    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *navigationAppearance = [UINavigationBarAppearance new];
        [navigationAppearance configureWithOpaqueBackground];
        navigationAppearance.backgroundColor = surface;
        navigationAppearance.shadowColor = UIColor.clearColor;
        navigationAppearance.titleTextAttributes = @{
            NSForegroundColorAttributeName: onSurface,
            NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]
        };
        navigationAppearance.largeTitleTextAttributes = @{
            NSForegroundColorAttributeName: onSurface,
            NSFontAttributeName: [UIFont systemFontOfSize:34 weight:UIFontWeightBold]
        };
        UINavigationBar *navigationBar = [UINavigationBar appearanceWhenContainedInInstancesOfClasses:@[NSClassFromString(@"LauncherNavigationController")]];
        navigationBar.standardAppearance = navigationAppearance;
        navigationBar.scrollEdgeAppearance = navigationAppearance;
        navigationBar.compactAppearance = navigationAppearance;
        navigationBar.tintColor = primary;

        UIToolbarAppearance *toolbarAppearance = [UIToolbarAppearance new];
        [toolbarAppearance configureWithOpaqueBackground];
        toolbarAppearance.backgroundColor = self.surfaceContainerColor;
        toolbarAppearance.shadowColor = UIColor.clearColor;
        UIToolbar *toolbar = [UIToolbar appearanceWhenContainedInInstancesOfClasses:@[NSClassFromString(@"LauncherNavigationController")]];
        toolbar.standardAppearance = toolbarAppearance;
        if (@available(iOS 15.0, *)) {
            toolbar.scrollEdgeAppearance = toolbarAppearance;
        }
        toolbar.tintColor = primary;
    }
}

+ (BOOL)shouldSkipViewController:(UIViewController *)viewController {
    for (NSString *name in @[@"LauncherMenuViewController", @"LauncherProfilesViewController",
                            @"PLPrefTableViewController", @"AccountListViewController",
                            @"DownloadProgressViewController"]) {
        Class permittedClass = NSClassFromString(name);
        if (permittedClass && [viewController isKindOfClass:permittedClass]) return NO;
    }
    return YES;
}

+ (void)applyToViewController:(UIViewController *)viewController {
    if ([self shouldSkipViewController:viewController] || !viewController.isViewLoaded) return;

    viewController.view.backgroundColor = self.surfaceColor;
    viewController.view.tintColor = self.primaryColor;
    viewController.navigationController.navigationBar.prefersLargeTitles = YES;
    viewController.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
    [self styleViewHierarchy:viewController.view];
}

+ (void)styleViewHierarchy:(UIView *)view {
    if ([view isKindOfClass:UITableView.class]) {
        [self styleTableView:(UITableView *)view];
    } else if ([view isKindOfClass:UITableViewCell.class]) {
        UITableViewCell *cell = (UITableViewCell *)view;
        UITableView *tableView = nil;
        UIView *parent = cell.superview;
        while (parent && ![parent isKindOfClass:UITableView.class]) parent = parent.superview;
        tableView = (UITableView *)parent;
        // Cells are styled by their data source, so semantic red/action colors
        // assigned there must not be overwritten by a later appearance pass.
        (void)tableView;
    } else if ([view isKindOfClass:UITextField.class]) {
        [self styleTextField:(UITextField *)view];
    } else if ([view isKindOfClass:UISegmentedControl.class]) {
        UISegmentedControl *control = (UISegmentedControl *)view;
        control.selectedSegmentTintColor = self.primaryContainerColor;
        [control setTitleTextAttributes:@{NSForegroundColorAttributeName: self.onPrimaryContainerColor}
                               forState:UIControlStateSelected];
        [control setTitleTextAttributes:@{NSForegroundColorAttributeName: self.onSurfaceVariantColor}
                               forState:UIControlStateNormal];
    }

    for (UIView *subview in view.subviews) {
        [self styleViewHierarchy:subview];
    }
}

+ (void)styleTableView:(UITableView *)tableView {
    tableView.backgroundColor = self.surfaceColor;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    tableView.sectionHeaderHeight = UITableViewAutomaticDimension;
    tableView.estimatedSectionHeaderHeight = 36;
    if (@available(iOS 15.0, *)) tableView.sectionHeaderTopPadding = 12;
}

+ (void)styleCell:(UITableViewCell *)cell inTableView:(UITableView *)tableView {
    cell.backgroundColor = UIColor.clearColor;
    UIView *background = [UIView new];
    background.backgroundColor = self.surfaceContainerColor;
    background.layer.cornerRadius = 14;
    background.layer.cornerCurve = kCACornerCurveContinuous;
    cell.backgroundView = background;
    cell.contentView.backgroundColor = UIColor.clearColor;
    cell.contentView.layer.cornerRadius = 14;
    cell.contentView.layer.cornerCurve = kCACornerCurveContinuous;
    cell.contentView.layer.masksToBounds = YES;
    cell.contentView.layoutMargins = UIEdgeInsetsMake(10, 16, 10, 16);
    if (![cell.textLabel.textColor isEqual:UIColor.systemRedColor]) {
        cell.textLabel.textColor = self.onSurfaceColor;
    }
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    cell.detailTextLabel.textColor = self.onSurfaceVariantColor;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    if (![cell.imageView.tintColor isEqual:UIColor.systemRedColor]) {
        cell.imageView.tintColor = self.primaryColor;
    }

    UIView *selected = [UIView new];
    selected.backgroundColor = self.primaryContainerColor;
    selected.layer.cornerRadius = 14;
    selected.layer.cornerCurve = kCACornerCurveContinuous;
    cell.selectedBackgroundView = selected;
}

+ (void)styleTextField:(UITextField *)textField {
    textField.backgroundColor = self.surfaceContainerHighColor;
    textField.textColor = self.onSurfaceColor;
    textField.layer.cornerRadius = MIN(16.0, CGRectGetHeight(textField.bounds) / 2.0);
    textField.layer.cornerCurve = kCACornerCurveContinuous;
    textField.layer.borderWidth = 1.0;
    textField.layer.borderColor = self.outlineColor.CGColor;
    textField.clipsToBounds = YES;
}

+ (void)styleFilledButton:(UIButton *)button {
    button.backgroundColor = self.primaryColor;
    button.tintColor = self.onPrimaryColor;
    [button setTitleColor:self.onPrimaryColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    button.layer.cornerRadius = MAX(18.0, CGRectGetHeight(button.bounds) / 2.0);
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.clipsToBounds = YES;
    button.contentEdgeInsets = UIEdgeInsetsMake(6, 8, 6, 8);
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.75;
}

@end

@interface UIViewController (AmethystMD3Theme)
- (void)amd3_viewWillAppear:(BOOL)animated;
@end

@implementation UIViewController (AmethystMD3Theme)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(viewWillAppear:));
        Method replacement = class_getInstanceMethod(self, @selector(amd3_viewWillAppear:));
        method_exchangeImplementations(original, replacement);
    });
}

- (void)amd3_viewWillAppear:(BOOL)animated {
    [self amd3_viewWillAppear:animated];
    [AmethystMD3Theme applyToViewController:self];
}

@end
