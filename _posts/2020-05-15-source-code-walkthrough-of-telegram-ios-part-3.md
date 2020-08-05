---
layout: post
title: "Source Code Walkthrough of Telegram-iOS Part 3: Other Foundations"
subtitle: ""
cover-img: "https://miro.medium.com/max/700/0*J0t9M0yYewxJV8Hs"
tags: [Telegram, iOS]
comments: true
---

Let me use one more post to finish the introduction of the foundation modules of the project.

# Logging

The module `TelegramCore` provides a simple [`logging`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/TelegramCore/Sources/Log.swift) implementation.

```swift
public final class Logger {
    private let queue = Queue(name: "org.telegram.Telegram.log", qos: .utility)
    
    // `false` in AppStore build
    public var logToFile: Bool
    
    // `false` in AppStore build
    public var logToConsole: Bool
    
    // `true` in AppStore build
    public var redactSensitiveData: Bool
    
    public static var shared: Logger
    
    public func log(_ tag: String, _ what: @autoclosure () -> String)
}

// for other modules
Logger.shared.log("Keychain", "couldn't get \(key) — not current")
```

It supports logging into the console and file system if flags are on. The `queue` is used to run file writings in a non-main thread. `redactSensitiveData` is for other codes to decide including sensitive data in a log message or not.

```swift
if Logger.shared.redactSensitiveData {
    messageText = "[[redacted]]"
} else {
    messageText = message.text
}
```

In public releases, the settings could still be changed via the in-app debugging controller that is introduced in the last section.

For modules that don’t depend on TelegramCore, the project setups bridge functions by [`registeredLoggingFunctions`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/TelegramCore/Sources/Network.swift#L156) in [`Network.swift`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/TelegramCore/Sources/Network.swift). It redirects the logging calls to the shared logger from modules like [MtProtoKit](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/MtProtoKit/Sources/MTLogging.m), [Postbox](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/Postbox/Sources/PostboxLogging.swift), and [TelegramApi](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/TelegramApi/Sources/TelegramApiLogger.swift).

It’s not a fancy framework that doesn’t even support logging levels. There are also many modules that don’t do logging at all or simply log via [`print`](https://github.com/TelegramMessenger/Telegram-iOS/search?l=Swift&q=print&type=Code)/[`NSLog`](https://github.com/TelegramMessenger/Telegram-iOS/search?q=NSLog&type=Code). It might need further clean up IMO. For example, the opened URL in a chat is logged to the system output via print in a [recent commit](https://github.com/TelegramMessenger/Telegram-iOS/commit/d5142c876e084bb2df39f0d56a8c2e12d961f91b#diff-7cef1a32e852176c8b9240cd5e3d5e40R8001), which doesn’t sound like a good idea.

# Crash Reporting

It’s reasonable that Telegram doesn’t use 3rd-party SDKs to prevent [leaks of user data](https://blog.zoom.us/wordpress/2020/03/27/zoom-use-of-facebook-sdk-in-ios-client/). It still surprises me that the project doesn’t have any built-in crash reporting module, not even a homegrown one. After looking into the commit histories, it did integrate Hockey SDK then removed it by commit `bdc0bb2` in January this year. The engineers may rely on the crash reports from AppStore to check stability issues.

Hockey SDK has been retired by Microsoft in the favor of [App Center](https://docs.microsoft.com/en-us/appcenter/transition/). Telegram-iOS uses an [App Center API](https://github.com/TelegramMessenger/Telegram-iOS/blob/b3ab501a75cd12ff079f32c299dea4a38ac61bba/submodules/TelegramUI/Sources/AppDelegate.swift#L2198) to check for updates. There is no integration with the SDK.

# Disk Storage

To support data sharing between the main app, watch app, intents app extension, the project stores most data inside a [group container folder](https://github.com/TelegramMessenger/Telegram-iOS/blob/b3ab501a75cd12ff079f32c299dea4a38ac61bba/submodules/TelegramUI/Sources/AppDelegate.swift#L373), named `telegram-data`. Some [legacy components](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/LegacyComponents/PublicHeaders/LegacyComponents/LegacyComponentsGlobals.h#L56) still use the [Documents](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/LegacyUI/Sources/TelegramInitializeLegacyComponents.swift#L374) folder. Below is a typical layout of `telegram-data`:

```swift
telegram-data/
|-- .tempkey  // the key for sqlcipher
|-- account-0123456789/ // data for account 0123456789
|   |-- network-stats/ // for `MTNetworkUsageManagerImpl`
|   |-- notificationsKey 
|   `-- postbox/ 
|       |-- db/
|       `-- media/ // media cache
|           |-- cache/
|           |-- short-cache/
|-- accounts-metadata/ // for `AccountManager`
|   |-- atomic-state/
|   |-- db/
|   |-- guard_db/
|   |-- media/
|   `-- spotlight/
|-- accounts-shared-data/
|-- lockState.json
|-- logs/  // log files
|-- notificationsPresentationData.json
|-- temp/
|   `-- app/
|-- widget-data/
`-- widgetPresentationData.json
```

Besides reading and writing files directly, the project mostly uses `SQLite` for structured data. Two SQLite extensions are enabled: [`SQLCipher`](https://github.com/TelegramMessenger/Telegram-iOS/tree/b3ab501a75cd12ff079f32c299dea4a38ac61bba/submodules/sqlcipher) for full database encryption and [`FTS5`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/Database/ValueBox/Sources/SqliteValueBox.swift#L617) for full-text search. This approach is popular in other popular messengers too, such as [WeChat](https://github.com/Tencent/wcdb) and [SignalApp](https://github.com/signalapp/Signal-iOS/tree/master/SignalServiceKit/src/Storage).

[LMDB](http://www.lmdb.tech/doc/), a BTree based transactional key-value store, is provided for a few Objective-C components: such as [`TGEmbedCoubPlayerView`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/LegacyComponents/Sources/TGEmbedCoubPlayerView.m) (the embedded player for [coub.com](http://coub.com/)), and [`TGMediaEditingContext`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/LegacyComponents/Sources/TGMediaEditingContext.m) that’s responsible for editing photos and videos while sending a media message.

# Network Transport

Messaging and VoIP calls are the two major scenarios that need network transport. Reliable connectivity and realtime update are vital characteristics of a messenger app, it’s a fascinating challenge as the global network environment is rather complex. Some engineering tricks were invented for it and were widely applied among messenger apps, such as traffic obfuscation, hybrid endpoint discovery, domain fronting, etc. I’ll try to write more on this topic in other articles.

[MTProto](https://core.telegram.org/mtproto), the core protocol of Telegram, was designed to support [multiple transport protocols](https://core.telegram.org/mtproto/transports). The current version of Telegram-iOS only supports [TCP transport](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/MtProtoKit/Sources/MTTcpTransport.m). The HTTP transport was [removed](https://github.com/TelegramMessenger/Telegram-iOS/commit/80c64348dcebe2c972ddfef1e2f78bf3c6109391) in 2018. The VoIP module [`libtgvoip`](https://github.com/telegramdesktop/libtgvoip/tree/522550a1e975b17e9048d7a2ab2d5b97cfc2f5d4) supports both UDP and TCP transports.

Telegram-iOS also leverages [VoIP notifications from PushKit](https://developer.apple.com/documentation/pushkit/responding_to_voip_notifications_from_pushkit) to receive data via Apple’s network. It’s another widely used trick that enables an app to encapsulate data in the notification payload and process it in the background without user interactions. The same behavior can’t be replicated by the normal APNS. It’s essential for some core features, like updating the unread count, retrieving new endpoints if the app can’t connect to the backend, updating live locations, etc.

As any abuse could cause a significant battery drain problem, Apple started to require apps to [invoke CallKit](https://developer.apple.com/videos/play/wwdc2019/707?time=624) after receiving VoIP notifications since the iOS SDK 13. But Telegram-iOS seems to survive from the new rule as it has got a special entitlement from Apple: [`com.apple.developer.pushkit.unrestricted-voip`](https://github.com/TelegramMessenger/Telegram-iOS/blob/2cad3d641d130274399e51355ff904ee33f15657/Telegram/Telegram-iOS/Telegram-iOS-AppStoreLLC.entitlements#L37). The same undocumented entitlement can also be found in [SignalApp](https://github.com/signalapp/Signal-iOS/blob/master/Signal/Signal-AppStore.entitlements#L22).

# UI Framework

Besides using [AsyncDisplayKit](https://github.com/TelegramMessenger/Telegram-iOS/tree/master/submodules/AsyncDisplayKit) as its core UI rendering framework, Telegram-iOS goes further and reimplements common UIKit controllers and views with it. Most UIKit components can find their counterparts inside the project: `NavigationController`, `TabBarController`, `AlertController`, `ActionSheetController`, `NavigationBar`, `ItemListController` (replacement of `UITableViewController`) etc. The approach is fairly reasonable, once you were bitten by the inconsistent behavior of system controllers across major iOS versions.

{: .box-note}
Off-Topic. It’s funny that most iOS engineers would eventually learn some swizzing tricks on UIKit. Somehow, reimplementing components like UINavigationController is not a trivial task as hacking the original one. One of my favorite details is how UINavigationController manages to push and pop a landscape only controller.

Regarding the UI property animation, [`POP`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/LegacyComponents/Sources/POPAnimation.mm) is the one for [legacy UI components](https://github.com/TelegramMessenger/Telegram-iOS/tree/master/submodules/LegacyComponents) in Objective-C, while the swift modules mostly use their own animator implementations upon [CADisplayLink](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/Display/Source/DisplayLinkAnimator.swift) or [CoreAnimation](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/Display/Source/CAAnimationUtils.swift).

Two Lottie libraries, [`rlottie`](https://github.com/TelegramMessenger/Telegram-iOS/tree/master/submodules/rlottie) and [`lottie-ios`](https://github.com/TelegramMessenger/Telegram-iOS/tree/master/submodules/lottie-ios), are built into the app to support After Effect animations. `rlottie` is mainly for [animated stickers](https://telegram.org/blog/animated-stickers) in thetgs format. `Lottie-ios` is used to load animation files from the [bundled resources](https://github.com/TelegramMessenger/Telegram-iOS/tree/master/submodules/TelegramUI/Resources/Animations). It seems there is actually no need for two libraries for the same thing, `lottie-ios` could be replaced by `rlottie`.

# Unit Test

There are basically no unit tests in the project.

# In-App Debugging

Tapping the setting tab for `10` times could present the [debug controller](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SettingsUI/Sources/DebugController.swift), in which you can tweak [log settings](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/TelegramCore/Sources/LoggingSettings.swift), collect logs, try [experimental UI settings](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/TelegramUIPreferences/Sources/ExperimentalUISettings.swift), etc.

![DebugController](/assets/tg-ios/part-3-DebugController.jpg){: .fit-img :}