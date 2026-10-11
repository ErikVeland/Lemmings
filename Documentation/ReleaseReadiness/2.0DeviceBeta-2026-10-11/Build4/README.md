# 2.0 build 4 iPad beta

GenErik iPad is now registered with Apple Developer. The annual device-list
update retained Cyberdeck, GenErik iPhone and Mac mini. The new device is
listed as GenErik iPad (iPad Pro 10.5-inch, iPad7,3, iPadOS 17.7.11).

Xcode beta 27.2 build 27B5019j produced a signed Release archive and development
IPA at `.build/ios-beta/2.0-4-ipad`. Version 2.0 build 4 includes the exact iPad
UDID in its provisioning profile. Signature, metadata, minimum iOS 16, arm64,
crash-symbol identity, compiled icons, privacy declarations and content checks
pass. All 120 Classic levels render and restore checkpoints after 50 ticks each.
The source manifest stayed unchanged through archive and export.

Mobile app code matches build 3. The only input changes are the beta build and
installation helpers and the recorded Mac-only Sparkle dependency condition.
The previously passing 19 core and 61 release-tooling tests remain the regression
evidence for those inputs. Mechanical validation stayed headless and muted.

Apple's `devicectl` installer successfully installed the verified candidate on
GenErik iPad. Its app query confirms `academy.glasscode.lemmings.ios`, version
2.0, bundle version 4. [Delivery evidence](delivery.json), [installation result](install.json)
and [installed app metadata](apps.json) record the exact result. The app was
not launched automatically. First launch, touch usability, rotation, saved-run
recovery and accessibility checks remain manual acceptance work.

The earlier iMazing CLI attempt failed because its separate CLI licence was not
activated. The standard GUI reported Installed, but the initial Apple query
returned an older build 1. The final direct Apple installation and exact build
query resolve that ambiguity. Those intermediate records remain preserved as
[CLI attempt](cli-delivery.json) and [GUI attempt](gui-delivery.json).
Apple Device Hub initially reported Developer Mode disabled. The owner received
the enable/restart/confirm steps; Apple's device service subsequently became
available for installation and app queries. No automatic first launch was used
to infer gameplay acceptance.

This is a Classic beta with 120 levels. L2/L3 mobile content, rendering and
campaigns, audio, Hot Seat, controller journeys, Duo layouts and physical-device
accessibility acceptance remain open. No TestFlight upload or publication occurred.
Builds 1–3 and the stable-Xcode build 3 App Store Connect export remain retained.

Evidence: [signed export](evidence.json), [frozen source](source-manifest.json),
[content manifest](content-manifest.json), [120-level checks](content-validation.json),
[Apple registration](device-registration.jpg).
