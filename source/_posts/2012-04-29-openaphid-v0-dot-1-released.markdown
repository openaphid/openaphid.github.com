---
layout: post
title: "OpenAphid v0.1 Released"
date: 2012-04-29 20:11
comments: true
categories: [OpenAphid, iOS, Release] 
---

## Overview of OpenAphid v0.1

We're excited to release OpenAphid v0.1, which is the first public version of the project.

Three github repositories have been created to meet different requirements:

+ `Runtime`: [https://github.com/openaphid/Runtime](https://github.com/openaphid/Runtime). As the core runtime of OpenAphid, it's an iOS static library project and is mainly written in C++. Besides porting the OpenGL ES rendering from [Cocos2d-iPhone](http://www.cocos2d-iphone.org/), it also manages the binding layer which exposes the 2D rendering as [JavaScript APIs](/api-doc/latest/index.html).

* `Demos`: [https://github.com/openaphid/Demos](https://github.com/openaphid/Demos). This repository includes several demos of OpenAphid. `PortedDemos` contains four iOS applications which are ported from [Cocos2d-iPhone](http://www.cocos2d-iphone.org/): NodeTest, SpriteTest, EffectTest and AdvEffectTest. They demonstrate how to manipulate nodes, sprites and actions in JavaScript APIs. `TankBenchmarks` is the benchmark described in our [previous post](/blog/2012/02/20/javascript-and-cocos2d-a-sneak-peek/). The implementation by using [ngCore](https://developer.mobage.com/) is also presented for your reference. You can build and run them on your iOS devices to reproduce the benchmark results.

* `Boilerplate-iOS`: [https://github.com/openaphid/Boilerplate-iOS](https://github.com/openaphid/Boilerplate-iOS). It's a template project for developing iOS games with OpenAphid. It's a good start point if you want to play with the APIs of OpenAphid by yourself.

The [JavaScript API references](/api-doc/latest/index.html) of OpenAphid v0.1 is also published. It's still a bit rough right now. We promise that it'll be improved in the future.

## Future of OpenAphid

v0.1 is just the start of OpenAphid. We admit that it's not ready for developing real product yet, but we'd like 