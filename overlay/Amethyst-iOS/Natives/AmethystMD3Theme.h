#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Material 3 design tokens used by the native launcher screens.
///
/// This class deliberately contains no global appearance proxies or method
/// swizzling. Every launcher surface opts in explicitly, so system dialogs,
/// document pickers, and the in-game surface keep their own appearance.
@interface AmethystMD3Theme : NSObject

+ (UIColor *)primaryColor;
+ (UIColor *)onPrimaryColor;
+ (UIColor *)primaryContainerColor;
+ (UIColor *)onPrimaryContainerColor;
+ (UIColor *)secondaryContainerColor;
+ (UIColor *)onSecondaryContainerColor;
+ (UIColor *)surfaceColor;
+ (UIColor *)surfaceContainerLowestColor;
+ (UIColor *)surfaceContainerLowColor;
+ (UIColor *)surfaceContainerColor;
+ (UIColor *)surfaceContainerHighColor;
+ (UIColor *)onSurfaceColor;
+ (UIColor *)onSurfaceVariantColor;
+ (UIColor *)outlineColor;
+ (UIColor *)errorColor;
+ (UIColor *)onErrorContainerColor;

/// Kept as a source-compatible entry point for older overlay code. It does
/// not install application-wide styling.
+ (void)applyGlobalAppearance;
+ (void)applyToViewController:(UIViewController *)viewController;

+ (void)styleTableView:(UITableView *)tableView;
+ (void)styleCell:(UITableViewCell *)cell inTableView:(UITableView *)tableView;
+ (void)styleTextField:(UITextField *)textField;
+ (void)styleFilledButton:(UIButton *)button;
+ (void)styleTonalButton:(UIButton *)button;
+ (void)styleSectionHeaderLabel:(UILabel *)label;
+ (void)styleCard:(UIView *)card;
+ (void)styleOutlinedCard:(UIView *)card;

@end

NS_ASSUME_NONNULL_END
