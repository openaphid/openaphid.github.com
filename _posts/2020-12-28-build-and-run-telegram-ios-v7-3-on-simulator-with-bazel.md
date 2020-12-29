---
layout: post
title: Build and Run Telegram-iOS v7.3 in Simulator with Bazel
date: 2020-12-28 19:06 -0800
tags: [Telegram, iOS]
cover-img: "/assets/tg-ios/build-bazel-buck.jpg"
---

Telegram-iOS released [v7.3](https://telegram.org/blog/voice-chats) last week with the new group voice chats and other improvements. My [previous post](https://hubo.dev/2020-11-20-build-and-run-telegram-on-xcode-12-x-simulator/) about building and running in Simulator is not working for several reasons:

- Buck is broken on Big Sur. The latest version 2020.10.21.01 gives an internal error as reported by [facebook/buck#2491](https://github.com/facebook/buck/issues/2491). Big Sur ships with a built-in dynamic linker cache, which breaks JNA from checking for dynamic library presence ([java-native-access/jna#1215](https://github.com/java-native-access/jna/issues/1215)). It's not officially fixed by Buck team for now except a workaround from Airbnb's fork [airbnb/buck#24](https://github.com/airbnb/buck/pull/24). 

- Telegram-iOS has upgraded the build toolchain to using Xcode 12, as well as the submodule webrtc. Some workarounds in my previous post are not necessary anymore.

Telegram-iOS project has been using Buck and Bazel in parallel as the build system for a while. It's now a good time for us to switch to Bazel on Big Sur.

# Instructions

My development machine runs macOS Big Sur v11.1 and Xcode 12.2 (12B45b). We can first use Homebrew to install Bazel and Yasm. Yasm is required to build some third-party dependencies.

```bash
brew install bazel yasm
```

Here is the version information on my machine:
```bash
$ bazel --version
bazel 3.7.2-homebrew

$ yasm --version
yasm 1.3.0
```

Let's clone the project code and switch to the tag `release-7.3`:

```bash
git clone --recursive https://github.com/TelegramMessenger/telegram-ios.git
cd telegram-ios
git checkout release-7.3
```

I want to reuse the fake distribution codesigning files that are present in the project, as it doesn't matter for running in Simulator. I need to apply a small change on `Makefile`:

```bash
sed -i'' -e 's/Telegram development/Telegram distribution/g' Makefile
```

The sed command replaces two occurrences of "Telegram development" with "Telegram distribution", which makes the build system not panic on the fake codesigning files. The diff is below for your reference:

```diff
diff --git a/Makefile b/Makefile
index 77b5d6d29..91a8e9484 100644
--- a/Makefile
+++ b/Makefile
@@ -453,7 +453,7 @@ bazel_project: kill_xcode
BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
BAZEL_HTTP_CACHE_URL="${BAZEL_HTTP_CACHE_URL}" \
TELEGRAM_DISABLE_EXTENSIONS="0" \
- build-system/prepare-build.sh Telegram development
+ build-system/prepare-build.sh Telegram distribution
APP_VERSION="${APP_VERSION}" \
BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
BAZEL_HTTP_CACHE_URL="${BAZEL_HTTP_CACHE_URL}" \
@@ -464,7 +464,7 @@ bazel_project_noextensions: kill_xcode
BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
BAZEL_HTTP_CACHE_URL="${BAZEL_HTTP_CACHE_URL}" \
TELEGRAM_DISABLE_EXTENSIONS="1" \
- build-system/prepare-build.sh Telegram development
+ build-system/prepare-build.sh Telegram distribution
APP_VERSION="${APP_VERSION}" \
BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
BAZEL_HTTP_CACHE_URL="${BAZEL_HTTP_CACHE_URL}" \
```

It's time to make the target `bazel_project_noextensions` or `bazel_project` to generate Xcode project files:

```bash
CODESIGNING_DATA_PATH="build-system/fake-codesigning" \
CODESIGNING_CERTS_VARIANT="distribution" \
CODESIGNING_PROFILES_VARIANT="appstore" \
COMMIT_ID=`git rev-parse HEAD` \
BUILD_NUMBER=`git rev-list --count HEAD` \
LOCAL_CODESIGNING=1 \
IGNORE_XCODE_VERSION_MISMATCH=1 \
sh build-system/verify.sh make bazel_project_noextensions
```

After Bazel saves the project file at `build-input/gen/project/Telegram.xcodeproj/`, Xcode will open it automatically. We can continue to build and run Telegram-iOS in Simulator. The build without extensions needs around 11 minutes on my machine. Please let me know what it takes on Apple M1 if you have one.

# Conclusion

It's smoother to build the project by Bazel. Another change I appreciate a lot is that all dependencies are targets with source code files instead of prebuilt binaries by Buck, it makes debugging much easier.
