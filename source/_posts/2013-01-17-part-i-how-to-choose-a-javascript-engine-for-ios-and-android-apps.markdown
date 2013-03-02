---
layout: post
title: "Part I: How to Choose a JavaScript Engine for iOS and Android Development"
date: 2013-01-17 15:30
comments: true
categories: [Tutorial, OpenAphid-Engine]
---

> DISCLAIMER: the post contains my personal opinions on the subject. I would appreciate it if you could correct my mistakes.

Back to the time when I started [OpenAphid-Engine][], there were already several similar iOS/Android projects. These projects, either commercial or open source, expose their core features by JavaScript language. For instance, [Titanium][] and [PhoneGap][] allow developers to use JavaScript to build native iOS/Android apps; [ngCore][] enables building cross platform games by pure JavaScript. JavaScript language has been chosen as a first-class citizen as it's one of the most popular programming language. It eases the learning curve and easily attracts developers into a new product ecosystem.

<!-- more -->

## How to Support JavaScript on iOS/Android

There are two main approaches to support JavaScript in an iOS/Android app. One method is to leverage the system browser component, [UIWebView][] on iOS and [WebView][] on Android; the other way is to compile and integrate a full-featured JavaScript engine.

Using the system component is easy to implement but it's inflexible and inefficient. [WebView][] provides [addJavascriptInterface][2] to inject Java classes into JavaScript context. But it only supports primitive data types which brings restrictions to API design; it's also unstable and crashes on Android simulator 2.3 and some real devices according to [issue #12987][3]. Things are worse on iOS, [UIWebView][] doesn't have public APIs to support direct interaction from JavaScript to Objective-C (You have to use private APIs to achieve the same functionality of [addJavascriptInterface][2]).

[PhoneGap][] is the most famous project that is built upon [UIWebView][] and [WebView][]. Developers are forced to use callbacks to retrieve return values from its JavaScript APIs, which is complex and inefficient especially for games.

Some earlier versions of [ngCore][] also relied on [UIWebView][] in order to support iOS. This mechanism has been replaced because of the awful performance.

In order to get better performance, flexibility and compatibility, it becomes popular by embedding a full featured JavaScript engine in native apps.

## Choices of JavaScript Engines

As far as I know, four JavaScript engines could be built and ran on iOS or Android: [JavaScriptCore][], [SpiderMonkey][], [V8][] and [Rhino][]. The table below lists their compatibilities on iOS and Android.

<table class="aphid-table">
	<tr>
		<th></th>
		<th>iOS</th>
		<th>Android</th>
	</tr>
	<tr>
		<td class="aphid-table-main-col">JavaScriptCore</td> <td>Interpreter only</td> <td>Interpreter and JIT</td> 
	</tr>
	<tr>
		<td class="aphid-table-main-col">SpiderMonkey</td> <td>Interpreter only</td> <td>Interpreter and JIT</td> 
	</tr>
	<tr>
		<td class="aphid-table-main-col">V8</td> <td>JIT only for jailbroken devices</td> <td>JIT</td> 
	</tr>
	<tr>
		<td class="aphid-table-main-col">Rhino</td> <td>Unsupported</td> <td>Interpreter</td> 
	</tr>
</table>

When I was searching for the right JavaScript engine for [OpenAphid-Engine][], my evaluation focused on the following metrics:

- Compatibility. The engine should support both iOS and Android, and work on both simulators and devices, which requires it support both ARM and x86.

- Stability. It should stably work on both platforms and supported CPU architectures.

- Extensibility. Extending the engine to add native features should be easy. For example, [OpenAphid-Engine][] required a bridge layer to access OpenGL ES from JavaScript.

- Performance. It's boiled down to two primary factors: fast JavaScript evaluation, and efficient binding mechanism with low overhead. [OpenAphid-Engine][] may trigger hundreds of OpenGL ES calls from JavaScript to render a single frame. The rendering would be slow if the overhead is much more significant than normal JavaScript routines.

- Small footprint. The memory footprint and binary size of the executable file should be small. 

[Rhino][] and [V8][] were out first since they don't support iOS. I really wanted to build [OpenAphid-Engine][] with [V8][], which showed great performance and elegant code structure during my preliminary experiment on Android. But I got disappointed due to the fact that [V8][] only employed a JIT mode while iOS doesn't allow JIT unless on a jailbroken device. Please refer to [issue #1312][4] if you need more technical details.

I debated a lot between [JavaScriptCore][] and [SpiderMonkey][]. After successfully built them on iOS and Android, I applied benchmarks and experiments to find the better one.

[SpiderMonkey][] is available under a more friendly license, but it lost in nearly all of my measurements compared to [JavaScriptCore][]. It generated larger binary file size (about 1.3MB larger for ARMv7); JavaScript evaluation was slower and the performance overhead of bridging JavaScript and C++ was also more significant. One more reason that pushed me away was that my build of [SpiderMonkey][] randomly crashed on iOS simulator.

The performance of a JavaScript engine can be affected by many factors, like the version of build toolchains, the version of engines, and the OS types etc. The chart below lists the running times of several micro-benchmarks with different builds of engines on an [iPod Touch 4][8]. Please check out the [Google Doc][5] if you're interested at the precise running times.

![benchmark](/images/js-engine-benchmark-ipod-touch4.png "Benchmark Results of JavaScriptCore and SpiderMonkeys on iPod Touch 4")

> + [JavaScriptCore][] is the clear winner by a large margin.

> + I failed to find my build of [SpiderMonkey][], so I used three other custom builds from [Cocos2d-iPhone-2.1-beta4][10], [Cocos2d-x-2.1-beta3][11] and [iMonkey][12].

> + All test apps were built with LLVM 4.1 in release mode; all engines were running in interpreter mode restricted by iOS.

> + Explanations of some benchmarks:

>	- `1m-js_loop` runs an empty loop for one million times.

>	- `1m-native_function` invokes an injected native function for 1M times while the native function simply returns undefined.

>	- `1m-js_function` is similar to the one above except the function is written in JavaScript.

>	- `fib(30)` calculates Fibonacci(30) in a recursive manner.

>	- `sudoku-5` solves five Sudoku problems with the algorithm from [this project][7].

> + `1m-native_function` for [JavaScriptCore][] was implemented by its portable [C APIs][6], which is not the most efficient way to inject native functions.

> + [SpiderMonkey][] is fast on desktop with its advanced method tracing JIT. But it's a whole different story on iOS devices.

> + The build from [iMonkey][12] was faster than other [SpiderMonkey][] builds in most benchmarks.

> + It's definitely possible to get better performance from [SpiderMonkey][] on iOS. [ngCore][] 1.10 for iOS managed to embed a custom build, which outperformed other [SpiderMonkey][] variants.

## Adventure with JavaScriptCore

My study proceeded further after I settled down with [JavaScriptCore][]:

1. The running time of `1m-native_function` was over six times longer than `1m-js_function` and `1m-Math.abs(0)` on [JavaScriptCore][]. I also observed the similar performance issue on accessing properties of injected native objects.

2. The [C APIs][6] had a clean design but was lack of flexible memory management APIs. It seemed difficult to resolve issues caused by [circular references][9] without deeper cooperation with the internal garbage collector.

3. There were many release versions of [JavaScriptCore][] available. The best one should be fast and compact for [OpenAphid-Engine][].

I abandoned the original plan of using the [C APIs][6] in order to solve problem 1 and 2. The version of JSC from iOS 4.3.3 was used, as it's faster than the version from iOS 5 in interpreter mode with a smaller binary executable file.

## Engines Used in Other Products

During the development of [OpenAphid-Engine][], I always kept my eyes on other products. The table below summarizes the JavaScript engines they are using underneath.

<table class="aphid-table">
	<tr>
		<th></th>
		<th>iOS</th>
		<th>Android</th>
	</tr>
	<tr>
		<td class="aphid-table-main-col">ngCore 1.6 and above</td> <td>UIWebView</td> <td>V8</td> 
	</tr>
	<tr>
		<td class="aphid-table-main-col">ngCore 1.7 and later</td> <td>SpiderMonkey</td> <td>V8</td> 
	</tr>
	<tr>
		<td class="aphid-table-main-col">Titanium</td> <td>JavaScriptCore</td> <td>V8 or Rhino</td> 
	</tr>
	<tr>
		<td class="aphid-table-main-col">PhoneGap</td> <td>UIWebView</td> <td>WebView</td> 
	</tr>
	<tr>
		<td class="aphid-table-main-col">Cocos2D-x JavaScript</td> <td>SpiderMonkey</td> <td>SpiderMonkey</td> 
	</tr>
	<tr>
		<td class="aphid-table-main-col">CocoonJS</td> <td>JavaScriptCore</td> <td>JavaScriptCore</td> 
	</tr>
	<tr>
		<td class="aphid-table-main-col">Ejecta</td> <td>JavaScriptCore</td> <td>Unsupported</td> 
	</tr>
	<tr>
		<td class="aphid-table-main-col">directCanvas</td> <td>JavaScriptCore</td> <td>No clue</td> 
	</tr>
</table>

## Next Story in Series

I will post my opinions on comparing [ngCore][] to [OpenAphid-Engine][]. Stay tuned!

[OpenAphid-Engine]: https://github.com/openaphid/runtime "OpenAphid-Engine"
[ngCore]: https://developer.mobage.com/ "ngCore"
[JavaScriptCore]: http://trac.webkit.org/wiki/JavaScriptCore "JavaScriptCore"
[V8]: http://code.google.com/p/v8/ "V8"
[SpiderMonkey]: https://developer.mozilla.org/en/docs/SpiderMonkey "SpiderMonkey"
[Rhino]: https://developer.mozilla.org/en-US/docs/Rhino "Rhino"
[Titanium]: http://www.appcelerator.com/platform/titanium-sdk/ "Titanium"
[UIWebView]: http://developer.apple.com/library/ios/#documentation/uikit/reference/UIWebView_Class/Reference/Reference.html "UIWebView"
[WebView]: http://developer.android.com/reference/android/webkit/WebView.html "WebView"
[PhoneGap]: http://phonegap.com/ "PhoneGap"


[1]: http://code.google.com/p/v8/issues/detail?id=2477
[2]: http://developer.android.com/reference/android/webkit/WebView.html#addJavascriptInterface%28java.lang.Object,%20java.lang.String%29
[3]: http://code.google.com/p/android/issues/detail?id=12987
[4]: http://code.google.com/p/v8/issues/detail?id=1312
[5]: https://docs.google.com/spreadsheet/ccc?key=0AmitMpjPL_UEdGVVdmlwWDBTa0lEbnlQWmw4dlNmTGc
[6]: http://trac.webkit.org/browser/trunk/Source/JavaScriptCore/API
[7]: https://github.com/attractivechaos/plb/blob/master/sudoku/sudoku_v2.js
[8]: http://en.wikipedia.org/wiki/IPod_Touch#Specifications
[9]: http://stackoverflow.com/questions/10092619/precise-explanation-of-javascript-dom-circular-reference-issue
[10]: http://cocos2d-iphone.googlecode.com/files/cocos2d-iphone-2.1-beta4.tar.gz
[11]: http://cocos2d-x.googlecode.com/files/cocos2d-2.1beta3-x-2.1.0.zip
[12]: https://github.com/couchbaselabs/iMonkey