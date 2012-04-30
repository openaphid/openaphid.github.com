---
layout: post
title: "OpenAphid v0.1 Released"
date: 2012-04-29 20:11
comments: true
categories: [OpenAphid, iOS, Release] 
---

### Overview of OpenAphid v0.1

We're excited to release OpenAphid v0.1, which is the first public version of the project.

Three github repositories have been created to meet different requirements:

<!-- more -->

+ `Runtime`: [https://github.com/openaphid/Runtime](https://github.com/openaphid/Runtime). As the core runtime of OpenAphid, it's an iOS static library project and is mainly written in C++. Besides porting the OpenGL ES rendering from [Cocos2d-iPhone](http://www.cocos2d-iphone.org/), it also manages the binding layer which exposes the 2D rendering as [JavaScript APIs](/api-doc/latest/index.html).

* `Demos`: [https://github.com/openaphid/Demos](https://github.com/openaphid/Demos). This repository includes several demos of OpenAphid. `PortedDemos` contains four iOS applications which are ported from [Cocos2d-iPhone](http://www.cocos2d-iphone.org/): NodeTest, SpriteTest, EffectTest and AdvEffectTest. They demonstrate how to manipulate nodes, sprites and actions in JavaScript APIs. `TankBenchmarks` is the benchmark described in our [previous post](/blog/2012/02/20/javascript-and-cocos2d-a-sneak-peek/). The implementation by using [ngCore](https://developer.mobage.com/) is also presented for your reference. You can build and run them on your iOS devices to reproduce the benchmark results.

* `Boilerplate-iOS`: [https://github.com/openaphid/Boilerplate-iOS](https://github.com/openaphid/Boilerplate-iOS). It's a template project for developing iOS games with OpenAphid. It's a good start point if you want to play with the APIs of OpenAphid by yourself.

The [JavaScript API references](/api-doc/latest/index.html) of OpenAphid v0.1 is also available. It's a bit rough right now. We promise that it'll be improved in the future.

### Highlights of OpenAphid v0.1

v0.1 is the start of OpenAphid. We admit that it's not ready for real product yet, but we'd like to highlight some characteristics of the project here.

- OpenAphid APIs can be considered as the "DOM" APIs for 2D games on mobile devices. The internal binding layer is implemented in the similar approach as [WebKit](http://www.webkit.org/) does for binding native objects to the JavaScript engine in browsers. 

- The memory occupied by native objects is managed automatically. Compared to some other script based game engines, OpenAphid doesn't provide destroy API at script side for any native objects. Native objects that are created in JavaScript are managed by the JavaScript garbage collector as other pure JavaScript objects. 

- OpenAphid follows the standard specifications to implement some core features. Although the rendering system of OpenAphid is ported from Cocos2d-iPhone, which is not supported in browsers; the other APIs in OpenAphid are designed to follow W3C standards. For example, the `console` object in global scope is provided as it is in browsers; the `XMLHttpRequest` APIs are partially implemented in v0.1, and will be fully compatible to W3C specification in the future releases. And the touch event handling in OpenAphid is implemented as the DOM touch event APIs, which is totally different from Cocos2d-iPhone.

- OpenAphid is fast and efficient. The benchmark result in the [previous post](/blog/2012/02/20/javascript-and-cocos2d-a-sneak-peek/) has been updated by using v0.1, which is slightly faster. We also evaluated the memory usage of OpenAphid with the same benchmark:

![Real memory usage of OpenAphid and ngcore](/images/tank_benchmark_mem_v0.1.jpg "Real memory")

> The data are captured by using the Activity Monitor of Xcode Instruments. The memory usage of the same benchmark on ngcore v1.6 is presented for reference only.

### Future of OpenAphid

We're working hard to improve OpenAphid. Most efforts are spent on the following tasks:

- Adds more features from Cocos2d-iPhone, like physics support, audio support, etc;

- Supports Android OS;

- Implements a set of flexible binding APIs for integrating 3rd-party services. The binding system in OpenAphid Runtime is designed to meet the performance requirement of OpenGL ES rendering, but it's not suitable for general purpose. A public binding system is planned to bridge JavaScript codes and Objective-C(or Java on Android in the future releases) easily. The Boilerplate project will be improved by integrating 3rd-party services, like analytics, in-app purchase, advertisement.

- Implements more W3C standard APIs, like making XMLHttpRequest fully compatible to specifications, adding FileSystem and WebSocket supports, etc;






