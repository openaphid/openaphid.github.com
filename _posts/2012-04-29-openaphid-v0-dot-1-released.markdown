---
layout: post
title: "OpenAphid-Engine v0.1 Released"
date: 2012-04-29 20:11
comments: true
tags: [OpenAphid-Engine, Release] 
---

We're excited to release OpenAphid-Engine v0.1, which is the first public version of the project.

Three GitHub repositories have been created:

<!-- more -->

+ `Runtime`: [https://github.com/openaphid/Runtime](https://github.com/openaphid/Runtime). As the core runtime of OpenAphid-Engine, it's an iOS static library project and is mainly written in C++. Besides porting the OpenGL ES rendering from [Cocos2d-iPhone](http://www.cocos2d-iphone.org/), it also manages the binding layer which exposes the 2D rendering as [JavaScript APIs](/api-doc/latest/index.html).

* `Demos`: [https://github.com/openaphid/Demos](https://github.com/openaphid/Demos). This repository includes several demos of OpenAphid-Engine. `PortedDemos` contains four iOS applications which are ported from [Cocos2d-iPhone](http://www.cocos2d-iphone.org/): NodeTest, SpriteTest, EffectTest and AdvEffectTest. They demonstrate how to manipulate nodes, sprites and actions in JavaScript APIs. `TankBenchmarks` is the benchmark described in our [previous post](/blog/2012/02/20/javascript-and-cocos2d-a-sneak-peek/). The implementation by using [ngCore](https://developer.mobage.com/) is also presented for your reference. You can build and run them on your iOS devices to reproduce the benchmark results.

* `Boilerplate-iOS`: [https://github.com/openaphid/Boilerplate-iOS](https://github.com/openaphid/Boilerplate-iOS). It's a template project for developing iOS games with OpenAphid-Engine. It's a good start point if you want to play with the APIs of OpenAphid-Engine by yourself.

The [JavaScript API references](/api-doc/latest/index.html) of OpenAphid-Engine v0.1 is also available. It's a bit rough right now. We promise that it'll be improved in the future.

## Highlights of OpenAphid-Engine v0.1

v0.1 is the start of OpenAphid-Engine. We admit that it's not ready for real product yet, but we'd like to present some characteristics of the project here.

- OpenAphid-Engine APIs can be considered as the "DOM" APIs for 2D games on mobile devices. The internal binding layer is implemented in the similar approach as [WebKit](http://www.webkit.org/) does for binding native objects to the JavaScript engine;

- The memory occupied by native objects is managed automatically. Compared to some other script based game engines, OpenAphid-Engine doesn't have destroy API at script level for any native objects. Native objects that are created in JavaScript are managed by the JavaScript garbage collector as other pure JavaScript objects. 

- OpenAphid-Engine follows the standard specifications to implement some core features. Although the rendering system of OpenAphid-Engine is ported from Cocos2d-iPhone, which is not supported in browsers; the other APIs in OpenAphid-Engine are designed to follow W3C standards. For example, the `console` object in global scope is provided as it is in browsers; the `XMLHttpRequest` APIs are partially implemented in v0.1, and will be fully compatible to its W3C specification in a future release. And the touch event handling in OpenAphid-Engine is implemented as the same as in DOM, which is totally different from Cocos2d-iPhone.

- OpenAphid-Engine is fast and efficient. The benchmark result in the [previous post](/blog/2012/02/20/javascript-and-cocos2d-a-sneak-peek/) has been updated by using v0.1, which is slightly faster. We also evaluated the memory usage of OpenAphid-Engine with the same benchmark (lower is better):

![Real memory usage of OpenAphid-Engine and ngcore](/images/tank_benchmark_mem_v0.1.jpg "Real memory")

> The data are captured by using the Activity Monitor of Xcode Instruments. The memory usage of the benchmark on ngcore v1.6 is presented for reference only.

## What's Next for OpenAphid-Engine

We're working hard to improve OpenAphid-Engine. Most efforts are spent on the following tasks:

- Ports more features from Cocos2d-iPhone, like physics support, audio support, etc;

- Supports Android OS;

- Provides binding APIs for integrating 3rd-party services. The binding system in OpenAphid-Engine Runtime is designed for the performance requirement of OpenGL ES rendering, but it's not suitable for general purpose. Another binding system is planned to bridge JavaScript codes and Objective-C(or Java on Android in the future releases) easily. The `Boilerplate-iOS` project will also be improved by integrating 3rd-party services, like analytics, in-app purchase, advertisement;

- Implements more W3C standard APIs, includes making XMLHttpRequest fully compatible to specifications, adding FileSystem and WebSocket supports, etc.

Please feel free to contact us with your questions and suggestions via `openaphid At gmail.com`. We’d appreciate it for your kind help.

## Special Thanks

We'd like to express our appreciation to [Oana Dobre](http://wannadobre.carbonmade.com/), who designed the cute aphid graphics and allowed us to use them for free.






