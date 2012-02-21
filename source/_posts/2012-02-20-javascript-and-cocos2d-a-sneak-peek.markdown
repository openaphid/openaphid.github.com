---
layout: post
title: "JavaScript and Cocos2D-iphone: a sneak peek"
date: 2012-02-20 23:26
comments: true
categories: [Open Aphid]
---
What is Open Aphid?
---------------------
*Open Aphid* is our secrect project to combine the power of JavaScript and Cocos2D-iphone for native game development on mobile devices. It allows developers to write fast and native quality games in JavaScript language. The architecture of Open Aphid can be summerized as below:

![architecture](images/architecture.jpg "Architecture of Open Aphid")

A set of Cocos2D-style JavaScript APIs are provided for composing scenes, applying actions on nodes, handling events, etc. The core runtime of Open Aphid is writted in C++, which adopts the architecture of Cocos2D-iphone. The JavaScript binding module bridges the C++ runtime and the JavaScript engine, which allows games to access native features in pure JavaScript.

We decided to implement the core of Open Aphid in C++ instead of reusing the Objective-C code base from Cocos2D-iphone. The first reason is for portability. The current WIP version is for iOS only as Cocos2D-iphone, but we'd like to support Android and other platforms after the iOS version is stable. The other consideration is for faster JavaScript binding. We want to reduce the performance overhead by adding a script layer as small as possible.

Why JavaScript?
---------------------
JavaScript is one of the most popular programming languages in the world. Open Aphid enables developers using a familiar language for mobile game development, and it can also make the development cycle in a web speed. At the development stage, developers can save the script and reload it on devices to see the changes instantly. No need to wait for compiling and redeploying anymore.

``` javascript
function test() {
	var a = 1;
}

function Tank() {
	
}
```

### Performance Comparison



![performance benchmark](images/benchmark_01.jpg "Benchmarks")

