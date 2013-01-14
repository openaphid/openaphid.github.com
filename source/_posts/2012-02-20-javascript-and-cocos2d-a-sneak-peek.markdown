---
layout: post
title: "JavaScript and Cocos2D-iPhone: a sneak peek of OpenAphid-Engine"
date: 2012-02-20 23:26
comments: true
categories: [OpenAphid-Engine]
---
## What is OpenAphid-Engine?

*OpenAphid-Engine* is our secret OSS project to combine the power of JavaScript and [Cocos2d-iPhone](http://www.cocos2d-iphone.org/) for native game development on mobile devices. It allows developers to write fast and native quality games in JavaScript language. The architecture of OpenAphid-Engine can be summarized as below:

<!-- more -->

![architecture](/images/architecture.jpg "Architecture of OpenAphid-Engine")

A set of Cocos2D-style JavaScript APIs are provided for composing scenes, applying actions on nodes, handling events, etc. The core runtime of OpenAphid-Engine is wrote in C++, which adopts the architecture of Cocos2d-iPhone. The JavaScript binding module bridges the C++ runtime and the JavaScript engine, which allows games to use native features in pure JavaScript.

We decided to implement the core of OpenAphid-Engine in C++ instead of reusing the Objective-C code base from Cocos2d-iPhone. The first reason is for portability. The current WIP version is for iOS only as Cocos2d-iPhone, but we'd like to support Android and other platforms after the iOS version is stable. The other consideration is for faster JavaScript binding. We want to reduce the performance overhead introduced by the script layer as small as possible.

Why use JavaScript?
-------------------
JavaScript is one of the most popular programming languages in the world. OpenAphid-Engine enables developers using a familiar language for mobile game development, and it can also make the development cycle in a web speed. 

At the development stage, developers can save the script and reload it on devices to see the changes instantly. No need to compile and re-deploy anymore.

OpenAphid-Engine is not the first one to bring JavaScript into native game development. There are several other frameworks which take the similar approaches. The most famous one is [ngCore](https://developer.mobage.com/) from [DeNA Co., Ltd](http://dena.jp/intl/).

Performance Benchmark Setup
---------------------------
We adopt a benchmark program introduced in [a presentation of ngCore SDK](http://www.slideshare.net/devsumi/17a6smartphone-xplatform). The program is modified a bit and implemented in Cocos2d-iPhone, ngCore and OpenAphid-Engine. The benchmark is composed by several parts, let's describe them using APIs from OpenAphid-Engine:

> ** Updates at 2012-04-28: ** code snippets were updated according to the API changes in v0.1 release.

##### A background image(Size 1024x1024)
``` javascript
var scene = new aphid.g2d.Scene();
var background = new aphid.g2d.Sprite(new aphid.g2d.Texture2D("background.png"));
scene.addChild(background);
```
#### A frame-by-frame animation(5 frames)
The animation is made from a 320x64 size image, which is originally included in a sample project of ngCore SDK:

![tank animation](/images/tank.png "Tank")
``` javascript
var texture = new aphid.g2d.Texture2D("tank.png");

var frames = [];
var imgSize = texture.contentSize;
for (var i = 0; i < 5; i++) {
	var frame = new aphid.g2d.SpriteFrame(
										texture, 
										new aphid.core.Rect(
															imgSize.width * i / 5, 
															0, 
															imgSize.width / 5, 
															imgSize.height
															)
										);
	frames.push(frame);
}
```
#### Tank moves per frame inside the screen
Dozens of small tanks are added to the scene. Each of them has a random initial position and changes it during each frame.
``` javascript
var tank = {} //declare a namespace
tank.maxTankCount = 1000;

tank.Tank = function(texture) {
	//fields
	this.sprite_ = new aphid.g2d.Sprite(texture);
	//the movement velocity and direction
	this.vx_ = Math.random() > 0.5 ? 0.1 : -0.1;
	this.vy_ = Math.random() > 0.5 ? 0.1 : -0.1;

	var winSize = aphid.g2d.director.winSize;
	//a random initial position
	this.sprite_.position = new aphid.core.Point(Math.random() * winSize.width, Math.random() * winSize.height);
	//setup and register frame update listener
	this.sprite_.onframeupdate = bind(this, this.handleFrameUpdate);
	this.sprite_.scheduleUpdate();
};

tank.Tank.prototype.getSprite = function() {return this.sprite_;};

tank.Tank.prototype.handleFrameUpdate = function(target, interval) {
		var p = this.sprite_.position;
		p.x += interval * 1000 * this.vx_;
		p.y += interval * 1000 * this.vy_;
		var size = aphid.g2d.director.winSize;
		if (p.x < 0) {
			p.x = 0;
			this.vx_ = -this.vx_;
		}
		
		if (p.x > size.width) {
			p.x = size.width;
			this.vx_ = -this.vx_;
		}
		
		if (p.y < 0) {
			p.y = 0;
			this.vy_ = -this.vy_;
		}
		
		if (p.y > size.height) {
			p.y = size.height;
			this.vy_ = -this.vy_;
		}
		this.sprite_.position = p;
};
```
#### Apply animation and add tanks to the scene
After applying the animation, the size of tank sprite is 64x64.
```javascript
var animation = new aphid.g2d.Animation(frames, 0.05);
var action = aphid.g2d.actions.repeatForever(
	aphid.g2d.actions.animate(animation, false)
	);

for (var i = 0; i < tank.maxTankCount; i++) {
	var newTank = new tank.Tank(frames[0].texture);
	newTank.getSprite().runAction(action.copy());
	scene.addChild(newTank.getSprite());
}
```
#### Run the scene
```javascript
	var director = aphid.g2d.director;
	director.runScene(scene);
```

A screenshot of the benchmark running with 100 tanks:

![screenshot of 100 tanks in OpenAphid-Engine](/images/screenshot_openaphid_100tanks.png "Screenshot")

Benchmark Environment
---------------------
The same benchmark is implemented in Cocos2d-iPhone, ngCore and OpenAphid-Engine. We tried to run it using the latest stable version of each:

+ [Cocos2d-iPhone 1.0.1](http://www.cocos2d-iphone.org/download). CCSpriteBatchNode is not used to make sure the benchmark share the same behavior in each framework. CC_DIRECTOR_FAST_FPS is also turned off for the same reason. CC_DIRECTOR_FPS_INTERVAL is set to 1.0f.
+ [ngCore 1.6-20120209](https://developer.mobage.com/). The performance of ngCore has improved a lot in this latest release than v0.9 which is used in the [presentation](http://www.slideshare.net/devsumi/17a6smartphone-xplatform).
+ OpenAphid-Engine. An internal stable release is used to run the test.

The benchmark is performed on an iPod Touch 3rd generation (32GB). The hardware specification can be found from its [wikipedia page](http://en.wikipedia.org/wiki/IPod_Touch).

### Benchmark Results
The FPS data are recorded for running different number of tanks on each framework. The FPS of ngCore is not consistent, so we tracked both the high and low FPS data.

> ** Updates at 2012-04-28: ** benchmark results are updated by using OpenAphid-Engine v0.1 release.

![performance benchmark](/images/tank_benchmark_fps_v0.1.jpg "Benchmark Results (Updated at 2012-04-28)")

OpenAphid-Engine gives a pleasant result. It's faster than ngCore and keeps 60 FPS when there are less than 200 tank sprites. The FPS is lower than Cocos2d-iPhone's when adding more tanks, it's acceptable as there are hundreds of native-to-JavaScript update callbacks to invoke during each frame. And we'll keep working to improve its performance.

When will OpenAphid-Engine be released?
---------------------------------
OpenAphid-Engine is still under development. We're working hard to make the first public release available in the middle of April. All source codes will be public then. Please feel free to mail us with your questions and suggestions via *openaphid At gmail.com*. We'd appreciate it for your kind help.
