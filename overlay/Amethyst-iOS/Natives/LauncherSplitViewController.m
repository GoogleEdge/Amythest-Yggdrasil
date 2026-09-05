#import "LauncherSplitViewController.h"
#import "LauncherMenuViewController.h"
#import "LauncherProfilesViewController.h"
#import "LauncherNavigationController.h"
#import "AmethystMD3Theme.h"
#import "LauncherPreferences.h"
#import "utils.h"

@interface LauncherSplitViewController () <UISplitViewControllerDelegate>
@property(nonatomic) CGSize lastLaidOutSize;
@end

@implementation LauncherSplitViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = AmethystMD3Theme.surfaceColor;
    self.delegate = self;

    if ([getPrefObject(@"control.control_safe_area") length] == 0) {
        setPrefObject(@"control.control_safe_area", NSStringFromUIEdgeInsets(getDefaultSafeArea()));
    }

    UINavigationController *masterNavigationController =
        [[UINavigationController alloc] initWithRootViewController:[LauncherMenuViewController new]];
    masterNavigationController.navigationBar.prefersLargeTitles = NO;

    LauncherNavigationController *contentNavigationController =
        [[LauncherNavigationController alloc] initWithRootViewController:[LauncherProfilesViewController new]];
    contentNavigationController.toolbarHidden = NO;

    self.viewControllers = @[masterNavigationController, contentNavigationController];

    // Material 3's navigation drawer/rail uses a stable readable width on
    // large screens and becomes an overlay drawer on compact screens.
    self.minimumPrimaryColumnWidth = 280.0;
    self.preferredPrimaryColumnWidth = 320.0;
    self.maximumPrimaryColumnWidth = 360.0;
    [self updateAdaptiveLayoutForSize:self.view.bounds.size];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self updateAdaptiveLayoutForSize:self.view.bounds.size];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize size = self.view.bounds.size;
    if (!CGSizeEqualToSize(size, self.lastLaidOutSize)) {
        [self updateAdaptiveLayoutForSize:size];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self updateAdaptiveLayoutForSize:size];
    (void)coordinator;
}

- (void)updateAdaptiveLayoutForSize:(CGSize)size {
    if (size.width <= 0.0 || size.height <= 0.0) return;
    self.lastLaidOutSize = size;

    BOOL isWide = size.width >= 700.0 &&
        self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular;
    BOOL hideSidebar = getPrefBool(@"general.hidden_sidebar");

    if (hideSidebar) {
        self.preferredDisplayMode = UISplitViewControllerDisplayModeSecondaryOnly;
    } else if (isWide) {
        self.preferredDisplayMode = UISplitViewControllerDisplayModeOneBesideSecondary;
    } else {
        self.preferredDisplayMode = UISplitViewControllerDisplayModeOneOverSecondary;
    }

    self.preferredSplitBehavior = isWide
        ? UISplitViewControllerSplitBehaviorTile
        : UISplitViewControllerSplitBehaviorOverlay;

    // Re-apply the width after changing display mode. This is important when
    // an iPad enters a multitasking size or rotates while the drawer is open.
    self.minimumPrimaryColumnWidth = isWide ? 280.0 : 260.0;
    self.preferredPrimaryColumnWidth = isWide ? 320.0 : 300.0;
    self.maximumPrimaryColumnWidth = isWide ? 360.0 : 340.0;
}

- (void)dismissViewController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
