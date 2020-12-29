---
layout: post
title: Build and Run Telegram-iOS v7.2 in Xcode 12.x Simulator with Buck
date: 2020-11-20 05:19 -0800
tags: [Telegram, iOS]
cover-img: "https://images.unsplash.com/photo-1587654780291-39c9404d746b"
---

> Please refer to [Build and Run Telegram-iOS v7.3 in Simulator with Bazel](/2020-12-28-build-and-run-telegram-ios-v7-3-on-simulator-with-bazel/) if you use macOS Big Sur

Telegram started the program of "[Reproducible Builds for iOS and Android](https://core.telegram.org/reproducible-builds)" to release its client source code in a more regular schedule. Although it's a great move, you may find it's still confusing how to build and run the iOS project with minimal effects. The [official guide](https://core.telegram.org/reproducible-builds#reproducible-builds-for-ios) is present to verify the build is reproducible, which requires an installation of macOS Catalina, Xcode 11.x, and other tools inside a Parallels virtual machine.

The guide has problems for developers who want to work with the code:

- Running another clone of macOS and Xcode needs a powerful machine.
- Xcode 11.x is outdated and the latest Xcode 12.x is [15 times faster](https://developer.apple.com/documentation/xcode-release-notes/xcode-12-release-notes) on code completion.
- It runs an automation script file to generate an IPA file without showing how to open the project in Xcode IDE.
- It doesn't cover how to build and run in Xcode simulator.

This tutorial illustrates my way to fix the issues. It involves installing the necessary tools and modify parts of the project code to make it work. You can fast forward to the final section if you don't want to read the details.

# Install Buck

My develop machine runs macOS Catalina 10.15.7 with Xcode 12.2 (12B45b). Telegram-iOS uses [**buck**](https://buck.build/) to build third-party libraries and generate Xcode workspace files. We can install buck and its dependency JDK 8 via Homebrew:

```bash
brew tap AdoptOpenJDK/openjdk
brew cask install adoptopenjdk8

brew tap facebook/fb
brew install buck
```

Please check your terminal session to make sure it's using JDK 8 and buck works:

```bash
$ java -version
openjdk version "1.8.0_272"
OpenJDK Runtime Environment (AdoptOpenJDK)(build 1.8.0_272-b10)
OpenJDK 64-Bit Server VM (AdoptOpenJDK)(build 25.272-b10, mixed mode)

$ buck --version
buck version 2020.10.21.01
```

# Build and Generate Xcode Workspace

## #1 Check Out the Code

```bash
git clone --recursive https://github.com/TelegramMessenger/telegram-ios.git
cd telegram-ios
```

## #2 Set Up Environment Variables

As Telegram-iOS enables developers to customize and build their own variants of clients, the build system takes a bunch of environment variables to feed the settings. We can reuse the settings from the reproducible builds guide as we only want to run it in Simulator.

```bash
export BUCK=buck
export BUILD_NUMBER=2020

export TELEGRAM_ENV_SET="1"
export DEVELOPMENT_CODE_SIGN_IDENTITY="iPhone Distribution: Digital Fortress LLC (C67CF9S4VU)"
export DISTRIBUTION_CODE_SIGN_IDENTITY="iPhone Distribution: Digital Fortress LLC (C67CF9S4VU)"
export DEVELOPMENT_TEAM="C67CF9S4VU"

export API_ID="8"
export API_HASH="7245de8e747a0d6fbe11f7cc14fcc0bb"

export BUNDLE_ID="ph.telegra.Telegraph"
export APP_CENTER_ID=""
export IS_INTERNAL_BUILD="true"
export IS_APPSTORE_BUILD="false"
export APPSTORE_ID="686449807"
export APP_SPECIFIC_URL_SCHEME="tgapp"

export ENTITLEMENTS_APP="Telegram-iOS/Telegram-iOS-AppStoreLLC.entitlements"
export DEVELOPMENT_PROVISIONING_PROFILE_APP="match Development ph.telegra.Telegraph"
export DISTRIBUTION_PROVISIONING_PROFILE_APP="match AppStore ph.telegra.Telegraph"
export ENTITLEMENTS_EXTENSION_SHARE="Share/Share-AppStoreLLC.entitlements"
export DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_SHARE="match Development ph.telegra.Telegraph.Share"
export DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_SHARE="match AppStore ph.telegra.Telegraph.Share"
export ENTITLEMENTS_EXTENSION_WIDGET="Widget/Widget-AppStoreLLC.entitlements"
export DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_WIDGET="match Development ph.telegra.Telegraph.Widget"
export DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_WIDGET="match AppStore ph.telegra.Telegraph.Widget"
export ENTITLEMENTS_EXTENSION_NOTIFICATIONSERVICE="NotificationService/NotificationService-AppStoreLLC.entitlements"
export DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_NOTIFICATIONSERVICE="match Development ph.telegra.Telegraph.NotificationService"
export DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_NOTIFICATIONSERVICE="match AppStore ph.telegra.Telegraph.NotificationService"
export ENTITLEMENTS_EXTENSION_NOTIFICATIONCONTENT="NotificationContent/NotificationContent-AppStoreLLC.entitlements"
export DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_NOTIFICATIONCONTENT="match Development ph.telegra.Telegraph.NotificationContent"
export DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_NOTIFICATIONCONTENT="match AppStore ph.telegra.Telegraph.NotificationContent"
export ENTITLEMENTS_EXTENSION_INTENTS="SiriIntents/SiriIntents-AppStoreLLC.entitlements"
export DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_INTENTS="match Development ph.telegra.Telegraph.SiriIntents"
export DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_INTENTS="match AppStore ph.telegra.Telegraph.SiriIntents"
export DEVELOPMENT_PROVISIONING_PROFILE_WATCH_APP="match Development ph.telegra.Telegraph.watchkitapp"
export DISTRIBUTION_PROVISIONING_PROFILE_WATCH_APP="match AppStore ph.telegra.Telegraph.watchkitapp"
export DEVELOPMENT_PROVISIONING_PROFILE_WATCH_EXTENSION="match Development ph.telegra.Telegraph.watchkitapp.watchkitextension"
export DISTRIBUTION_PROVISIONING_PROFILE_WATCH_EXTENSION="match AppStore ph.telegra.Telegraph.watchkitapp.watchkitextension"

export CODESIGNING_PROFILES_VARIANT="appstore"
export PACKAGE_METHOD="appstore"
```

I add minor tweaks to the original settings in [build-system/verify.sh](https://github.com/openaphid/Telegram-iOS/blob/main/build-system/verify.sh):

- Add `BUCK` variable. The `makefile` depends on it to locate the buck command.
- Add `BUILD_NUMBER` variable.
- Flip `IS_INTERNAL_BUILD` to `true` and `IS_APPSTORE_BUILD` to `false`.

## #3 Enable Dead Code Stripping

We need to enable dead code stripping for all modules by adding it to [Config/utils.bzl](https://github.com/openaphid/Telegram-iOS/blob/main/Config/utils.bzl):

```patch
diff --git a/Config/utils.bzl b/Config/utils.bzl
index ca0271275..26570381c 100644
--- a/Config/utils.bzl
+++ b/Config/utils.bzl
@@ -50,6 +50,7 @@ SHARED_CONFIGS = {
     "ONLY_ACTIVE_ARCH": "YES",
     "LD_RUNPATH_SEARCH_PATHS": "@executable_path/Frameworks",
     "ENABLE_BITCODE": "NO",
+    "DEAD_CODE_STRIPPING": "YES",
 }
```

Otherwise, you may encounter the following error while building the project with Xcode:

```console
Undefined symbols for architecture x86_64:
  "_swift_getFunctionReplacement", referenced from:
      _swift_getFunctionReplacement50 in libswiftCompatibilityDynamicReplacements.a(DynamicReplaceable.cpp.o)
     (maybe you meant: _swift_getFunctionReplacement50)
  "_swift_getOrigOfReplaceable", referenced from:
      _swift_getOrigOfReplaceable50 in libswiftCompatibilityDynamicReplacements.a(DynamicReplaceable.cpp.o)
     (maybe you meant: _swift_getOrigOfReplaceable50)
ld: symbol(s) not found for architecture x86_64
```

## #4 Tweak Build Settings of mozjpeg

The build settings of some third-party libraries don't have the `x86_64` target that is required by simulator unless you have an Apple M1 computer. We need to add it by ourselves.

`mozjpeg` is one of them that needs a tweak. Inside [third-party/mozjpeg/BUCK](https://github.com/openaphid/Telegram-iOS/blob/main/third-party/mozjpeg/BUCK), it declares two targets of `arm64` and `armv7`. We can change `armv7` to `x86_64` as we don't need `armv7` in Simulator and on most devices.

```patch
diff --git a/third-party/mozjpeg/BUCK b/third-party/mozjpeg/BUCK
index 379603ce4..708e0201f 100644
--- a/third-party/mozjpeg/BUCK
+++ b/third-party/mozjpeg/BUCK
@@ -48,7 +48,7 @@ genrule(
   cp $BUILD_DIR/mozjpeg/jmorecfg.h "$OUT/Public/mozjpeg/"
   cp $BUILD_DIR/build/jconfig.h "$OUT/Public/mozjpeg/"

-    BUILD_ARCH="armv7"
+    BUILD_ARCH="x86_64"

   BUILD_DIR="$OUT/$BUILD_ARCH"
   rm -rf "$BUILD_DIR"
@@ -62,8 +62,8 @@ genrule(

   PATH="$PATH:$CMAKE_DIR/bin" sh $BUILD_DIR/build-mozjpeg-buck.sh $BUILD_ARCH "$BUILD_DIR/mozjpeg" "$BUILD_DIR"

-    lipo -create $OUT/arm64/build/libjpeg.a $OUT/armv7/build/libjpeg.a -output $OUT/Public/lib/libjpeg.a
-    lipo -create $OUT/arm64/build/libturbojpeg.a $OUT/armv7/build/libturbojpeg.a -output $OUT/Public/lib/libturbojpeg.a
+    lipo -create $OUT/arm64/build/libjpeg.a $OUT/x86_64/build/libjpeg.a -output $OUT/Public/lib/libjpeg.a
+    lipo -create $OUT/arm64/build/libturbojpeg.a $OUT/x86_64/build/libturbojpeg.a -output $OUT/Public/lib/libturbojpeg.a
   """,
   out = "libmozjpeg",
   visibility = [
```

## #5 Fix Build for webrtc-ios

Telegram-iOS builds its video calls upon `webrtc-ios`, which is a gigantic module imported this year. It's supposed to be built to a framework by buck before generating workspace files. Unfortunately, the code in the official repo doesn't compile with Xcode 12.x and doesn't support the `x86_64` target.

The first change is on a python script [find_sdk.py](https://github.com/ali-fareed/webrtc-ios/blob/782743c7931d09c1d2e4a0cf6cd349ee45452f1d/src/build/mac/find_sdk.py) which is a part of `webrtc-ios` build system. It helps to locate the SDK path in Xcode.app. The original regular expression `^MacOSX(10\.\d+)\.sdk$` doesn't work against Xcode 12.x, as the SDK pathname has been changed to `Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX11.0.sdk`. We need to change the expression to `^MacOSX(1[01]\.\d+)\.sdk$`, which matches both `MacOSX10` and `MacOSX11` SDK names.

```diff
diff --git a/third-party/webrtc/webrtc-ios/src/build/mac/find_sdk.py b/third-party/webrtc/webrtc-ios/src/build/mac/find_sdk.py
index 38c28832..44cb85c0 100755
--- a/third-party/webrtc/webrtc-ios/src/build/mac/find_sdk.py
+++ b/third-party/webrtc/webrtc-ios/src/build/mac/find_sdk.py
@@ -88,7 +88,7 @@ def main():
     raise SdkError('Install Xcode, launch it, accept the license ' +
       'agreement, and run `sudo xcode-select -s /path/to/Xcode.app` ' +
       'to continue.')
-  sdks = [re.findall('^MacOSX(10\.\d+)\.sdk$', s) for s in os.listdir(sdk_dir)]
+  sdks = [re.findall('^MacOSX(1[01]\.\d+)\.sdk$', s) for s in os.listdir(sdk_dir)]
   sdks = [s[0] for s in sdks if s]  # [['10.5'], ['10.6']] => ['10.5', '10.6']
   sdks = [s for s in sdks  # ['10.5', '10.6'] => ['10.6']
           if parse_version(s) >= parse_version(min_sdk_version)]
```

The other fix is to add `x86_64` target to [third-party/webrtc/BUCK](https://github.com/openaphid/Telegram-iOS/blob/main/third-party/webrtc/BUCK) as following:

```diff
diff --git a/third-party/webrtc/BUCK b/third-party/webrtc/BUCK
index 6762598ed..28bd2f3bd 100644
--- a/third-party/webrtc/BUCK
+++ b/third-party/webrtc/BUCK
@@ -37,11 +37,11 @@ genrule(

     sh $SRCDIR/build-webrtc-buck.sh "$BUILD_DIR" $BUILD_ARCH

-    BUILD_ARCH=arm
+    BUILD_ARCH=x64

-    BUILD_DIR_ARMV7="$SRCDIR/$BUILD_ARCH"
+    BUILD_DIR_X64="$SRCDIR/$BUILD_ARCH"

-    BUILD_DIR="$BUILD_DIR_ARMV7"
+    BUILD_DIR="$BUILD_DIR_X64"

     rm -rf "$BUILD_DIR"
     mkdir -p "$BUILD_DIR"
@@ -61,7 +61,7 @@ genrule(
     sh $SRCDIR/build-webrtc-buck.sh "$BUILD_DIR" $BUILD_ARCH

     mkdir -p "$OUT"
-    lipo -create "$BUILD_DIR_ARMV7/webrtc-ios/src/out/ios/obj/sdk/libframework_objc_static.a" "$BUILD_DIR_ARM64/webrtc-ios/src/out/ios_64/obj/sdk/libframework_objc_static.a" -output "$OUT/libframework_objc_static.a"
+    lipo -create "$BUILD_DIR_X64/webrtc-ios/src/out/ios_sim/obj/sdk/libframework_objc_static.a" "$BUILD_DIR_ARM64/webrtc-ios/src/out/ios_64/obj/sdk/libframework_objc_static.a" -output "$OUT/libframework_objc_static.a"
 """,
     out = "libwebrtc",
     visibility = ["PUBLIC"]
```

# #6 Generate Workspace Files

Now it's ready to run the command below to build libraries and generate workspace files:

```bash
make project
```

It might take a while to finish as it needs to build libraries like openssl, ffmpeg, and webrtc-ios. Once it finishes, it opens Xcode IDE with the generated workspace file at `Telegram/Telegram_Buck.xcworkspace`.

# Build and Run in Simulator

It's exciting to see Xcode is running, but there is one last change we need. Otherwise, the build process to run in Simulator fails with many link stage errors:

```console
Undefined symbols for architecture x86_64:
  "static UIKit.UIPointerShape.defaultCornerRadius.getter : CoreGraphics.CGFloat", referenced from:
      Display.(PointerInteractionImpl in _B39DD7E7F85F24DF4F7212BCFE28692F).pointerInteraction(_: __C.UIPointerInteraction, styleFor: __C.UIPointerRegion) -> __C.UIPointerStyle? in PointerInteraction.o
  "enum case for UIKit.UIPointerShape.roundedRect(UIKit.UIPointerShape.Type) -> (__C.CGRect, CoreGraphics.CGFloat) -> UIKit.UIPointerShape", referenced from:
      Display.(PointerInteractionImpl in _B39DD7E7F85F24DF4F7212BCFE28692F).pointerInteraction(_: __C.UIPointerInteraction, styleFor: __C.UIPointerRegion) -> __C.UIPointerStyle? in PointerInteraction.o
  "enum case for UIKit.UIPointerEffect.highlight(UIKit.UIPointerEffect.Type) -> (__C.UITargetedPreview) -> UIKit.UIPointerEffect", referenced from:
      Display.(PointerInteractionImpl in _B39DD7E7F85F24DF4F7212BCFE28692F).pointerInteraction(_: __C.UIPointerInteraction, styleFor: __C.UIPointerRegion) -> __C.UIPointerStyle? in PointerInteraction.o
```

Symbols about pointer interactions can't be found by linker. I don't know the real reason behind it. It may be an issue of Xcode or buck may generate some incorrect project files. My fix is to comment out the code using pointer interactions inside [submodules/Display/Source/PointerInteraction.swift](https://github.com/openaphid/Telegram-iOS/blob/main/submodules/Display/Source/PointerInteraction.swift#L44) as I'm not going to test the feature in Simulator.

```diff
diff --git a/submodules/Display/Source/PointerInteraction.swift b/submodules/Display/Source/PointerInteraction.swift
index 3a60a7e02..f8204f92b 100644
--- a/submodules/Display/Source/PointerInteraction.swift
+++ b/submodules/Display/Source/PointerInteraction.swift
@@ -41,6 +41,7 @@ private final class PointerInteractionImpl: NSObject, UIPointerInteractionDelega

     func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
         var pointerStyle: UIPointerStyle? = nil
+        /*
         if let interactionView = interaction.view {
             let targetedPreview = UITargetedPreview(view: interactionView)
             switch self.style {
@@ -63,6 +64,7 @@ private final class PointerInteractionImpl: NSObject, UIPointerInteractionDelega
                     pointerStyle = UIPointerStyle(effect: .hover(targetedPreview, preferredTintMode: .none, prefersShadow: false, prefersScaledContent: false))
             }
         }
+         */
         return pointerStyle
     }
```

Now you should be able to build, run, and debug Telegram-iOS in Simulator. 

# Fast Forward

If you don't have time to enjoy the fun to fight with a complex build system and want to fast forward to the final stage, I've put the changes as patch files to my [forked repo of Telegram-iOS](https://github.com/openaphid/Telegram-iOS). You can check out the official repo and run the commands to download and use the patches which simplify the process:

```bash
# Install buck
brew tap AdoptOpenJDK/openjdk
brew cask install adoptopenjdk8
brew tap facebook/fb
brew install buck

# Check out the code
git clone --recursive https://github.com/TelegramMessenger/telegram-ios.git
cd telegram-ios
git checkout release-7.2

# Download and apply enviroment variables
wget https://raw.githubusercontent.com/openaphid/Telegram-iOS/main/hack_env.sh
source hack_env.sh

# Download and apply code patches
wget https://raw.githubusercontent.com/openaphid/Telegram-iOS/main/Xcode12_simulator_build.patch
git apply Xcode12_simulator_build.patch

# Build and generate Xcode workspace files
make project
```