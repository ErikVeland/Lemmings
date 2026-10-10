// Loaded only by the test runner. Mute output without changing game preferences.
#import <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static BOOL MuteTestAudio(void) {
    const char *mode = getenv("LEMMINGS_TEST_AUDIO");
    return mode && strcmp(mode, "muted") == 0;
}

static BOOL OfflineTestRender(AVAudioEngine *engine) {
    return engine.isInManualRenderingMode && engine.manualRenderingMode == AVAudioEngineManualRenderingModeOffline;
}

static void SwapAudio(Class cls, SEL original, SEL replacement) {
    method_exchangeImplementations(class_getInstanceMethod(cls, original),
                                   class_getInstanceMethod(cls, replacement));
}

@interface AVAudioEngine (LemmingsTestSilence)
@end
@implementation AVAudioEngine (LemmingsTestSilence)
+ (void)load {
    if (MuteTestAudio()) SwapAudio(self, @selector(startAndReturnError:), @selector(lemmingsTest_startAndReturnError:));
}
- (BOOL)lemmingsTest_startAndReturnError:(NSError **)error {
    // Offline buffers have no device output and must retain measurable samples.
    if (!OfflineTestRender(self)) self.mainMixerNode.outputVolume = 0;
    return [self lemmingsTest_startAndReturnError:error];
}
@end

@interface AVAudioMixerNode (LemmingsTestSilence)
@end
@implementation AVAudioMixerNode (LemmingsTestSilence)
+ (void)load {
    if (MuteTestAudio()) SwapAudio(self, @selector(setOutputVolume:), @selector(lemmingsTest_setOutputVolume:));
}
- (void)lemmingsTest_setOutputVolume:(float)volume {
    // Keep internal mix levels and playback clocks available to mechanical tests.
    [self lemmingsTest_setOutputVolume:self.engine.mainMixerNode == self && !OfflineTestRender(self.engine) ? 0 : volume];
}
@end

@interface NSSound (LemmingsTestSilence)
@end
@implementation NSSound (LemmingsTestSilence)
+ (void)load {
    if (!MuteTestAudio()) return;
    SwapAudio(self, @selector(play), @selector(lemmingsTest_play));
    SwapAudio(self, @selector(setVolume:), @selector(lemmingsTest_setVolume:));
}
- (BOOL)lemmingsTest_play {
    self.volume = 0;
    return [self lemmingsTest_play];
}
- (void)lemmingsTest_setVolume:(float)volume {
    [self lemmingsTest_setVolume:0];
}
@end

@interface AVAudioPlayer (LemmingsTestSilence)
@end
@implementation AVAudioPlayer (LemmingsTestSilence)
+ (void)load {
    if (!MuteTestAudio()) return;
    SwapAudio(self, @selector(play), @selector(lemmingsTest_play));
    SwapAudio(self, @selector(playAtTime:), @selector(lemmingsTest_playAtTime:));
    SwapAudio(self, @selector(setVolume:), @selector(lemmingsTest_setVolume:));
    SwapAudio(self, @selector(setVolume:fadeDuration:), @selector(lemmingsTest_setVolume:fadeDuration:));
}
- (BOOL)lemmingsTest_play {
    self.volume = 0;
    return [self lemmingsTest_play];
}
- (BOOL)lemmingsTest_playAtTime:(NSTimeInterval)time {
    self.volume = 0;
    return [self lemmingsTest_playAtTime:time];
}
- (void)lemmingsTest_setVolume:(float)volume {
    [self lemmingsTest_setVolume:0];
}
- (void)lemmingsTest_setVolume:(float)volume fadeDuration:(NSTimeInterval)duration {
    [self lemmingsTest_setVolume:0 fadeDuration:0];
}
@end

@interface AVPlayer (LemmingsTestSilence)
@end
@implementation AVPlayer (LemmingsTestSilence)
+ (void)load {
    if (!MuteTestAudio()) return;
    SwapAudio(self, @selector(play), @selector(lemmingsTest_play));
    SwapAudio(self, @selector(setRate:), @selector(lemmingsTest_setRate:));
    SwapAudio(self, @selector(playImmediatelyAtRate:), @selector(lemmingsTest_playImmediatelyAtRate:));
    SwapAudio(self, @selector(setMuted:), @selector(lemmingsTest_setMuted:));
    SwapAudio(self, @selector(setVolume:), @selector(lemmingsTest_setVolume:));
}
- (void)lemmingsTest_play {
    self.muted = YES;
    [self lemmingsTest_play];
}
- (void)lemmingsTest_setRate:(float)rate {
    self.muted = YES;
    [self lemmingsTest_setRate:rate];
}
- (void)lemmingsTest_playImmediatelyAtRate:(float)rate {
    self.muted = YES;
    [self lemmingsTest_playImmediatelyAtRate:rate];
}
- (void)lemmingsTest_setMuted:(BOOL)muted {
    [self lemmingsTest_setMuted:YES];
}
- (void)lemmingsTest_setVolume:(float)volume {
    [self lemmingsTest_setVolume:0];
}
@end

// NSSound.beep() is imported from this C function rather than an ObjC method.
static void TestBeep(void) {
    if (!MuteTestAudio()) NSBeep();
}
__attribute__((used)) static struct { const void *replacement; const void *original; }
TestBeepInterpose __attribute__((section("__DATA,__interpose"))) = {
    (const void *)TestBeep, (const void *)NSBeep
};
