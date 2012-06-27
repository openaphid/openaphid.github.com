---
layout: post
title: "OpenAphid Android v0.1 released"
date: 2012-06-27 08:22
comments: true
categories: 
---

We're excited to release the first version of OpenAphid which supports Android OS. OpenAphid is now a cross platform 2D game engine with both iOS and Android support.

Several github repositories have been updated, please check them out for more details:

<!-- more -->

- [https://github.com/openaphid/Runtime](https://github.com/openaphid/Runtime) is updated with the Android related codes. You can check it out and build it with Android NDK.

- [https://github.com/openaphid/Demos](https://github.com/openaphid/Demos) is also refreshed with the Android project files. You can download the prebuilt APK files to test them on your Android devices: [https://github.com/openaphid/Demos](https://github.com/openaphid/Demos)

- [https://github.com/openaphid/Boilerplate-iOS](https://github.com/openaphid/Boilerplate-iOS) is a new template project for developing Android games with OpenAphid.

## Highlights and Limitations of OpenAphid Android v0.1

It's the beginning of cross platform support of OpenAphid. Please consider it as an alpha release. But we'd like to summarize some implementation highlights here:

- The core runtime shares the same code base with the iOS version, which makes new features can be added to both platforms in the future.

- The same JavaScript engine is used on both platforms, which saves us from building a proxy layer to support different engines on different platforms as other solutions do. It also brings better performance which we'll prove later.

- The project is built with the standard Android NDK, no private or undocumented APIs are used.

This release is lack of several important features comparing to the iOS version. We're planning another release to make it catch up in the near future.

- The native library is built for `armeabi-v7a` only in this release. `armeabi` support will be included in the next release.

- `JavaScript JIT compiler` is not enabled. We've done some experiments to enable it on Android OS, which shows promising performance gains for computation intensive tasks and regular expressions. But we decided to disable it now as we didn't spend enough time on evaluating its stability.

- `JavaScript to Dalvik Java binding` is not implemented. `XMLHttpRequest` is absent too.

- This version doesn't reload textures automatically when the GL context is destroyed. It simply finishes the activity if GL context is lost. We're working on a better way to handle it.

## Performance Benchmark

The same tank program as introduced in our [previous post](/blog/2012/02/20/javascript-and-cocos2d-a-sneak-peek/) is used to evaluate the performance of OpenAphid on Android OS. Several other Android 2D game engines are chose as references:

- [cocos2d-x 1.0.1-0.13.0](http://www.cocos2d-x.org/projects/cocos2d-x/wiki/Download), a C++ port of `cocos2d-iphone` which supports Android OS.

- [cocos2d-android-1](http://code.google.com/p/cocos2d-android-1/), another port of `cocos2d-iphone` which is implemented in pure Java.

- [Ngcore 1.8](https://developer.mobage.com/), a commercial game engine from DeNA which also uses JavaScript and OpenGL ES.

The benchmark is performed on a [Motorola DEFY+ MB526](http://developer.motorola.com/products/defyplus-mb526/) phone, which has a 1GHz processor and a 854x480 sized screen. Its Android OS version is 2.3.6. 

We captured the average FPS in 5 seconds for displaying different number of tanks with each engine:

![performance benchmark](/images/tank_banckmark_android_v0.1.jpg "Benchmark Results")

OpenAphid shows great performance again as we can tell from this chart. It's on par with `cocos2d-x`, and faster than others. 

`cocos2d-android-1` suffers from the frequently GC pauses of Dalvik VM as observed from logcat. `Ngcore` is the slowest engine once again, and its rendering is also buggy in this test. The dirty area in black color should have been cleared in the screenshot below, we've filed a bug report about it to Ngcore:

![Ngcore Rendering Bug](/images/ngcore_rendering_bug.jpg "Demonstrating the rendering bug of Ngcore")

## About the Next Release

The next release will make the Android version catch up all features as the iOS version. JavaScript to Dalvik Java binding APIs will be introduced to make integrating 3rd-party services become cross platform too. We'll add new features simultaneously to both iOS and Android versions after that release.

Stay Tuned!
