---
layout: post
title: "OpenAphid-Engine v0.2.1f Release and Discontinuation Announcement"
date: 2013-01-14 14:09
comments: true
categories: [OpenAphid-Engine, Release]
---
[OpenAphid-Engine][] was born as an exploration project at the first half year of 2012 when I quit my day job. Its mission was to figure out the most efficient way to integrate a full JavaScript engine within native iOS/Android games. 

<!-- more -->

The development went perfectly well as it even outperformed the commercial solution of [ngCore][] from DeNA. I really enjoyed the pleasure brought by tackling technical problems to make the engine support both iOS and Android with high performance. I also gained precious experiences after studying source codes of JavaScriptCore and other great open source projects.

But I failed to find enough time working on it after I started a long travel plan with my family at Aug 2012. After careful consideration, I have decided it's time to sunset the project as I'm going to find a long-term job again. For developers who are also interested at using a JavaScript engine within native apps, I'll write two or three more articles in these days to share some pieces of knowledge collected during the development of [OpenAphid-Engine][].

v0.2.1f is the final update of [OpenAphid-Engine][]. The release comes with bug fixes for iOS6 support and performance improvements on Android. The [iOS demo project](https://github.com/openaphid/Demos/tree/master/iOS) has been revamped by merging separated demos into one single app. It also illustrates the ability to use [CoffeeScript][] and [TypeScript][] to write games with [OpenAphid-Engine][].

## Release notes of OpenAphid-Engine v0.2.1f

- (Android) Adds `libOpenAphid_JIT.so` which includes a JIT enabled JavaScriptCore. It can significantly boost performance for computation intense tasks in JavaScript. For instance, the running time of `fibonacci(30)` drops to ~140ms from ~780ms on a Nexus 7, while Java on Dalvik VM takes 280ms～350ms to finish the calculation.
```javascript
function fibonacci(n) { return n < 2 ? n : (fib(n-1) + fib(n-2)); }
```

- (Android) Improves rendering performance when a texture has premultiplied alpha values.

- (Android) Fixes a crash when loading JNI libs on Android 4.0+ devices by using toolchains from Android NDK r8c.

- (Android) Demo app has been refined. [APK files](https://github.com/openaphid/Demos/tree/master/Android/Demos/apk).

- (iOS) Orientation on iOS6 now works correctly.

- (iOS) Fixes compilation errors under llvm_4.1.

- (iOS) New all-in-one demo app with ARC enabled. [Project files](https://github.com/openaphid/Demos/tree/master/iOS).

- Samples of using CoffeeScript and TypeScript with [OpenAphid-Engine][]. Please refer to [coffee_tank.coffee](https://github.com/openaphid/Demos/blob/master/iOS/OpenAphid-Demos/demo.bundle/coffee_tank.coffee) and [type_tank.ts](https://github.com/openaphid/Demos/blob/master/iOS/OpenAphid-Demos/demo.bundle/type_tank.ts) for more details.

![screenshot](/images/openaphid-0.2.1f-demos.png "Screenshot of New iOS&Android Demo App")

## About Github Repositories

The main source codes of [OpenAphid Runtime](https://github.com/openaphid/Runtime) and [AJ](https://github.com/openaphid/AJ) (the modified JavaScript Engine) have been moved into folders named `DISCONTINUED`.

## Acknowledgments

I appreciate everyone's support to [OpenAphid-Engine][]. And special thanks to [Wanna Dobre](http://wannadobre.carbonmade.com/), who kindly designed the wonderful [aphid character](http://wannad.deviantart.com/gallery/#/d4zzsk5) for the project and for this blog site.

[OpenAphid-Engine]: https://github.com/openaphid/runtime "OpenAphid-Engine"
[ngCore]: https://developer.mobage.com/ "ngCore"
[CoffeeScript]: http://coffeescript.org/ "CoffeeScript"
[TypeScript]: http://www.typescriptlang.org/ "TypeScript"