#import "AmethystMD3Theme.h"

#include <stdint.h>

static UIColor *AMD3Color(uint32_t lightHex, uint32_t darkHex) {
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

static UIFont *AMD3ScaledFont(UIFontTextStyle style, CGFloat size, UIFontWeight weight) {
    UIFont *font = [UIFont systemFontOfSize:size weight:weight];
    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:style] scaledFontForFont:font];
    }
    return font;
}

@implementation AmethystMD3Theme

+ (UIColor *)primaryColor { return AMD3Color(0x6750A4, 0xD0BCFF); }
+ (UIColor *)onPrimaryColor { return AMD3Color(0xFFFFFF, 0x381E72); }
+ (UIColor *)primaryContainerColor { return AMD3Color(0xEADDFF, 0x4F378B); }
+ (UIColor *)onPrimaryContainerColor { return AMD3Color(0x21005D, 0xEADDFF); }
+ (UIColor *)secondaryContainerColor { return AMD3Color(0xE8DEF8, 0x4A4458); }
+ (UIColor *)onSecondaryContainerColor { return AMD3Color(0x1D192B, 0xE8DEF8); }
+ (UIColor *)surfaceColor { return AMD3Color(0xFFFBFE, 0x141218); }
+ (UIColor *)surfaceContainerLowestColor { return AMD3Color(0xFFFFFF, 0x0F0D13); }
+ (UIColor *)surfaceContainerLowColor { return AMD3Color(0xF7F2FA, 0x1D1B20); }
+ (UIColor *)surfaceContainerColor { return AMD3Color(0xF3EDF7, 0x211F26); }
+ (UIColor *)surfaceContainerHighColor { return AMD3Color(0xECE6F0, 0x2B2930); }
+ (UIColor *)onSurfaceColor { return AMD3Color(0x1D1B20, 0xE6E0E9); }
+ (UIColor *)onSurfaceVariantColor { return AMD3Color(0x49454F, 0xCAC4D0); }
+ (UIColor *)outlineColor { return AMD3Color(0x79747E, 0x938F99); }
+ (UIColor *)errorColor { return AMD3Color(0xBA1A1A, 0xFFB4AB); }
+ (UIColor *)onErrorContainerColor { return AMD3Color(0x410002, 0x690005); }

+ (void)applyGlobalAppearance {
    // Intentionally empty. A global UIAppearance swizzle was the source of
    // cross-screen regressions in the previous design.
}

+ (void)applyToViewController:(UIViewController *)viewController {
    if (!viewController.isViewLoaded) return;

    viewController.view.backgroundColor = self.surfaceColor;
    viewController.view.tintColor = self.primaryColor;

    UINavigationController *navigationController = [viewController isKindOfClass:UINavigationController.class]
        ? (UINavigationController *)viewController
        : viewController.navigationController;
    if (!navigationController) return;

    navigationController.navigationBar.tintColor = self.primaryColor;
    navigationController.navigationBar.prefersLargeTitles = YES;
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = self.surfaceColor;
        appearance.shadowColor = UIColor.clearColor;
        appearance.titleTextAttributes = @{
            NSForegroundColorAttributeName: self.onSurfaceColor,
            NSFontAttributeName: AMD3ScaledFont(UIFontTextStyleHeadline, 17, UIFontWeightSemibold)
        };
        appearance.largeTitleTextAttributes = @{
            NSForegroundColorAttributeName: self.onSurfaceColor,
            NSFontAttributeName: AMD3ScaledFont(UIFontTextStyleLargeTitle, 34, UIFontWeightBold)
        };
        navigationController.navigationBar.standardAppearance = appearance;
        navigationController.navigationBar.scrollEdgeAppearance = appearance;
        navigationController.navigationBar.compactAppearance = appearance;
    }
}

+ (void)styleTableView:(UITableView *)tableView {
    tableView.backgroundColor = self.surfaceColor;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    tableView.rowHeight = UITableViewAutomaticDimension;
    tableView.estimatedRowHeight = 64.0;
    tableView.sectionHeaderHeight = UITableViewAutomaticDimension;
    tableView.estimatedSectionHeaderHeight = 42.0;
    tableView.sectionFooterHeight = 0.0;
    tableView.contentInset = UIEdgeInsetsMake(8.0, 0.0, 20.0, 0.0);
    tableView.scrollIndicatorInsets = UIEdgeInsetsMake(8.0, 0.0, 20.0, 0.0);
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 12.0;
    }
}

+ (void)styleCard:(UIView *)card {
    card.backgroundColor = self.surfaceContainerColor;
    card.layer.cornerRadius = 24.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.masksToBounds = YES;
}

+ (void)styleOutlinedCard:(UIView *)card {
    card.backgroundColor = self.surfaceColor;
    card.layer.cornerRadius = 20.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = self.outlineColor.CGColor;
    card.layer.masksToBounds = YES;
}

+ (void)styleCell:(UITableViewCell *)cell inTableView:(UITableView *)tableView {
    cell.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = UIColor.clearColor;
    cell.contentView.layoutMargins = UIEdgeInsetsMake(10.0, 16.0, 10.0, 16.0);
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.font = AMD3ScaledFont(UIFontTextStyleBody, 16.0, UIFontWeightMedium);
    if (!cell.textLabel.textColor) cell.textLabel.textColor = self.onSurfaceColor;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.font = AMD3ScaledFont(UIFontTextStyleCaption1, 13.0, UIFontWeightRegular);
    if (!cell.detailTextLabel.textColor) cell.detailTextLabel.textColor = self.onSurfaceVariantColor;
    if (!cell.imageView.tintColor) cell.imageView.tintColor = self.primaryColor;

    UIView *background = [UIView new];
    [self styleCard:background];
    cell.backgroundView = background;

    UIView *selectedBackground = [UIView new];
    selectedBackground.backgroundColor = self.primaryContainerColor;
    selectedBackground.layer.cornerRadius = 24.0;
    selectedBackground.layer.cornerCurve = kCACornerCurveContinuous;
    selectedBackground.layer.masksToBounds = YES;
    cell.selectedBackgroundView = selectedBackground;

    // Keep grouped tables readable without imposing a fixed width. The
    // system's readable content width handles iPhone, iPad, and split view.
    if (@available(iOS 9.0, *)) {
        cell.preservesSuperviewLayoutMargins = YES;
        cell.separatorInset = UIEdgeInsetsMake(0.0, CGFLOAT_MAX, 0.0, 0.0);
    }
    (void)tableView;
}

+ (void)styleTextField:(UITextField *)textField {
    textField.backgroundColor = self.surfaceContainerHighColor;
    textField.textColor = self.onSurfaceColor;
    textField.tintColor = self.primaryColor;
    textField.font = AMD3ScaledFont(UIFontTextStyleBody, 16.0, UIFontWeightRegular);
    textField.layer.cornerRadius = 16.0;
    textField.layer.cornerCurve = kCACornerCurveContinuous;
    textField.layer.borderWidth = 1.0;
    textField.layer.borderColor = self.outlineColor.CGColor;
    textField.clipsToBounds = YES;
    if (textField.leftView) {
        textField.leftView.tintColor = self.onSurfaceVariantColor;
    }
}

+ (void)styleFilledButton:(UIButton *)button {
    button.backgroundColor = self.primaryColor;
    button.tintColor = self.onPrimaryColor;
    [button setTitleColor:self.onPrimaryColor forState:UIControlStateNormal];
    [button setTitleColor:self.onPrimaryColor forState:UIControlStateHighlighted];
    button.titleLabel.font = AMD3ScaledFont(UIFontTextStyleHeadline, 15.0, UIFontWeightSemibold);
    button.layer.cornerRadius = 20.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.clipsToBounds = YES;
    button.contentEdgeInsets = UIEdgeInsetsMake(10.0, 20.0, 10.0, 20.0);
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.75;
}

+ (void)styleTonalButton:(UIButton *)button {
    button.backgroundColor = self.secondaryContainerColor;
    button.tintColor = self.onSecondaryContainerColor;
    [button setTitleColor:self.onSecondaryContainerColor forState:UIControlStateNormal];
    button.titleLabel.font = AMD3ScaledFont(UIFontTextStyleHeadline, 15.0, UIFontWeightSemibold);
    button.layer.cornerRadius = 20.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.clipsToBounds = YES;
    button.contentEdgeInsets = UIEdgeInsetsMake(10.0, 16.0, 10.0, 16.0);
}

+ (void)styleSectionHeaderLabel:(UILabel *)label {
    label.textColor = self.onSurfaceVariantColor;
    label.font = AMD3ScaledFont(UIFontTextStyleSubheadline, 14.0, UIFontWeightSemibold);
    label.numberOfLines = 0;
    label.adjustsFontForContentSizeCategory = YES;
}

@end
