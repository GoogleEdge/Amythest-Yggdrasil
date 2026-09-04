#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AmethystMD3Theme : NSObject

+ (UIColor *)primaryColor;
+ (UIColor *)onPrimaryColor;
+ (UIColor *)primaryContainerColor;
+ (UIColor *)onPrimaryContainerColor;
+ (UIColor *)surfaceColor;
+ (UIColor *)surfaceContainerColor;
+ (UIColor *)surfaceContainerHighColor;
+ (UIColor *)onSurfaceColor;
+ (UIColor *)onSurfaceVariantColor;
+ (UIColor *)outlineColor;

+ (void)applyGlobalAppearance;
+ (void)applyToViewController:(UIViewController *)viewController;
+ (void)styleTableView:(UITableView *)tableView;
+ (void)styleCell:(UITableViewCell *)cell inTableView:(UITableView *)tableView;
+ (void)styleTextField:(UITextField *)textField;
+ (void)styleFilledButton:(UIButton *)button;

@end

NS_ASSUME_NONNULL_END
