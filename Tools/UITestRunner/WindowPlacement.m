// Loaded only by the native test runner. Never linked into the game.
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

static NSRect TestFrame(NSRect frame) {
    NSArray<NSScreen *> *screens = NSScreen.screens;
    if ([NSProcessInfo.processInfo.environment[@"LEMMINGS_TEST_WINDOWS"] isEqualToString:@"secondary"] && screens.count > 1) {
        NSRect area = screens[1].visibleFrame;
        if (frame.size.width <= area.size.width && frame.size.height <= area.size.height) {
            frame.origin = NSMakePoint(NSMidX(area) - frame.size.width / 2,
                                       NSMaxY(area) - frame.size.height);
            return frame;
        }
    }
    CGFloat right = 0, top = 0;
    for (NSScreen *screen in screens) {
        right = MAX(right, NSMaxX(screen.frame));
        top = MAX(top, NSMaxY(screen.frame));
    }
    frame.origin = NSMakePoint(right + 1024, top + 1024);
    return frame;
}

static void Swap(Class cls, SEL original, SEL replacement) {
    method_exchangeImplementations(class_getInstanceMethod(cls, original),
                                   class_getInstanceMethod(cls, replacement));
}

static void RejectActivation(void) {
    fprintf(stderr, "Desktop activation requires LEMMINGS_TEST_WINDOWS=foreground.\n");
    exit(2);
}

@interface NSWindow (LemmingsTestPlacement)
@end

@implementation NSWindow (LemmingsTestPlacement)
+ (void)load {
    const char *mode = getenv("LEMMINGS_TEST_WINDOWS");
    if (!mode || strcmp(mode, "foreground") == 0) return;
    Swap(self, @selector(setFrame:display:), @selector(lemmingsTest_setFrame:display:));
    Swap(self, @selector(constrainFrameRect:toScreen:), @selector(lemmingsTest_constrainFrameRect:toScreen:));
    Swap(self, @selector(orderWindow:relativeTo:), @selector(lemmingsTest_orderWindow:relativeTo:));
    Swap(self, @selector(makeKeyAndOrderFront:), @selector(lemmingsTest_makeKeyAndOrderFront:));
}
- (void)lemmingsTest_setFrame:(NSRect)frame display:(BOOL)display {
    [self lemmingsTest_setFrame:TestFrame(frame) display:display];
}
- (NSRect)lemmingsTest_constrainFrameRect:(NSRect)frame toScreen:(NSScreen *)screen {
    return TestFrame(frame);
}
- (void)lemmingsTest_orderWindow:(NSWindowOrderingMode)place relativeTo:(NSInteger)otherWindow {
    if (place != NSWindowOut) {
        self.animationBehavior = NSWindowAnimationBehaviorNone;
        [self setFrame:TestFrame(self.frame) display:NO];
    }
    [self lemmingsTest_orderWindow:place relativeTo:otherWindow];
}
- (void)lemmingsTest_makeKeyAndOrderFront:(id)sender {
    // Responder-chain tests still use real views. Desktop focus is opt-in.
    [self orderFront:sender];
}
@end

@interface NSApplication (LemmingsTestActivation)
@end

@implementation NSApplication (LemmingsTestActivation)
+ (void)load {
    const char *mode = getenv("LEMMINGS_TEST_WINDOWS");
    if (!mode || strcmp(mode, "foreground") == 0) return;
    Swap(self, @selector(activateIgnoringOtherApps:), @selector(lemmingsTest_activateIgnoringOtherApps:));
    if (strcmp(mode, "offscreen") == 0) {
        Swap(self, @selector(setActivationPolicy:), @selector(lemmingsTest_setActivationPolicy:));
    }
    if (class_getInstanceMethod(self, NSSelectorFromString(@"activate"))) {
        Swap(self, NSSelectorFromString(@"activate"), @selector(lemmingsTest_activate));
    }
}
- (BOOL)lemmingsTest_setActivationPolicy:(NSApplicationActivationPolicy)policy {
    // Accessory apps can activate during finishLaunching even without an
    // explicit activate call. Bitmap tests must stay background-only.
    return [self lemmingsTest_setActivationPolicy:NSApplicationActivationPolicyProhibited];
}
- (void)lemmingsTest_activateIgnoringOtherApps:(BOOL)flag {
    // Do not let a test take keyboard ownership from the player's game.
    RejectActivation();
}
- (void)lemmingsTest_activate {
    RejectActivation();
}
@end
