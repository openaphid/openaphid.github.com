---
layout: post
title: "JavaScript and Cocos2D-iphone: a sneak peek of Open Aphid"
date: 2012-02-20 23:26
comments: true
categories: [Open Aphid]
---
What is Open Aphid?
---------------------
*Open Aphid* is our secret project to combine the power of JavaScript and [Cocos2d-iPhone](http://www.cocos2d-iphone.org/) for native game development on mobile devices. It allows developers to write fast and native quality games in JavaScript language. The architecture of Open Aphid can be summarized as below:

![architecture](images/architecture.jpg "Architecture of Open Aphid")

A set of Cocos2D-style JavaScript APIs are provided for composing scenes, applying actions on nodes, handling events, etc. The core runtime of Open Aphid is written in C++, which adopts the architecture of Cocos2d-iPhone. The JavaScript binding module bridges the C++ runtime and the JavaScript engine, which allows games to use native features in pure JavaScript.

We decided to implement the core of Open Aphid in C++ instead of reusing the Objective-C code base from Cocos2d-iPhone. The first reason is for portability. The current WIP version is for iOS only as Cocos2d-iPhone, but we'd like to support Android and other platforms after the iOS version is stable. The other consideration is for faster JavaScript binding. We want to reduce the performance overhead introduced by the script layer as small as possible.

Why use JavaScript?
-------------------
JavaScript is one of the most popular programming languages in the world. Open Aphid enables developers using a familiar language for mobile game development, and it can also make the development cycle in a web speed. 

At the development stage, developers can save the script and reload it on devices to see the changes instantly. No need to compile and re-deploy anymore.

Open Aphid is not the first one to bring JavaScript into native game development. There are several other frameworks which take the similar approaches. The most famous one is [ngCore](https://developer.mobage.com/) from [DeNA Co., Ltd](http://dena.jp/intl/).

Performance Benchmark Setup
---------------------------
We adopt a benchmark program introduced in [a presentation of ngCore SDK](http://www.slideshare.net/devsumi/17a6smartphone-xplatform). The program is modified a bit and implemented in Cocos2d-iPhone, ngCore and Open Aphid. The benchmark is composed by several parts, lets describe them using APIs from Open Aphid:

##### A background image(Size 1024x1024)
``` javascript
var scene = new G2D.Scene();
var background = new G2D.Sprite("background.png");
scene.addChild(background);
```
#### A frame-by-frame animation(5 frames)
The animation is made from a 320x64 size image, which is originally included in a sample project of ngCore SDK:

![tank animation](images/tank.png "Tank")
``` javascript
var texture = new G2D.Texture2D("tank.png");

var frames = [];
var imgSize = texture.contentSize;
for (var i = 0; i < 5; i++) {
	var frame = new G2D.SpriteFrame(
					texture, 
					new Core.Rect(
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
function Tank(texture) {
	this.sprite = new G2D.Sprite(texture);
	//set a random initial position
	this.sprite.position = new Core.Point(Math.random() * 320, Math.random() * 480);
	
	//set the movement velocity and direction
	this.vx = Math.random() > 0.5 ? 0.1 : -0.1;
	this.vy = Math.random() > 0.5 ? 0.1 : -0.1;
	
	this.getSprite = function() {
		return this.sprite;
	};

	//invoked for each frame
	this.onUpdate = function(interval) {
		var p = this.sprite.position;
		p.x += interval * 1000 * this.vx;
		p.y += interval * 1000 * this.vy;
		
		var size = G2D.director.winSize;
		
		//make sure tank is inside the screen
		if (p.x < 0) {
			p.x = 0;
			this.vx = -this.vx;
		}
		
		if (p.x > size.width) {
			p.x = size.width;
			this.vx = -this.vx;
		}
		
		if (p.y < 0) {
			p.y = 0;
			this.vy = -this.vy;
		}
		
		if (p.y > size.height) {
			p.y = size.height;
			this.vy = -this.vy;
		}
		
		//set the new position
		this.sprite.position = p;
	};
	
	//register and schedule the onUpdate listener
	this.sprite.onUpdate = this;
	this.sprite.scheduleUpdate();
}
```
#### Apply animation and add tanks to the scene
After applying the animation, the size of tank sprite is 64x64.
```javascript
var tankCount = 100; //The benchmark tests the FPS for different count of tanks
for (var i = 0; i < tankCount; i++) {
	var tank = new Tank(texture);
	scene.addChild(tank.getSprite()); //add to scene

	//create animation
	var animation = new G2D.Animation(frames);
	animation.delay = 0.05;
	
	//apply the animation action to sprite, make it repeat forever
	var action = new G2D.Actions.Animate(animation, false);
	tank.getSprite().runAction(new G2D.Actions.RepeatForever(action));
}
```
#### Run the scene and display FPS on screen
```javascript
	var director = G2D.director;
	director.displayFPS = true;
	director.runWithScene(scene);
```

A screenshot of the benchmark running with 100 tanks:

![screenshot of 100 tanks in Open Aphid](images/screenshot_openaphid_100tanks.png "Screenshot")

Benchmark Environment
---------------------
The same benchmark is implemented in Cocos2d-iPhone, ngCore and Open Aphid. We tried to run it using the latest stable version of each:

+ [Cocos2d-iPhone 1.0.1](http://www.cocos2d-iphone.org/download). CCSpriteBatchNode is not used to make sure the benchmark share the same behavior in each framework. CC_DIRECTOR_FAST_FPS is also turned off for the same reason. CC_DIRECTOR_FPS_INTERVAL is set to 1.0f.
+ [ngCore 1.6-20120209-g4a0717e](https://developer.mobage.com/). The performance of ngCore has improved a lot in this latest release than v0.9 which is used in the [presentation](http://www.slideshare.net/devsumi/17a6smartphone-xplatform).
+ Open Aphid. An internal stable release is used to run the test.

The benchmark is performed on an iPod Touch 3rd generation (32GB). The hardware specification can be found from its [wikipedia page](http://en.wikipedia.org/wiki/IPod_Touch).

### Benchmark Results
The FPS data are recorded for running different number of tanks on each framework. The FPS of ngCore is not consistent, so we tracked both the high and low FPS data.

![performance benchmark](images/benchmark_01.jpg "Benchmarks")

Open Aphid gives a pleasant result. It can keep 60 FPS when there are less than 200 tank sprites. The FPS is lower than Cocos2d-iPhone when adding more tanks, but we can accept it as there are hundreds of native-to-JavaScript update callbacks invoked during each frame.

When will OA be released?
-------------------------
Open Aphid is still under development. We're working hard to make the first public release available in the middle of April. Please feel free to mail us with your questions and suggestions via *openaphid At gmail.com*. We'd appreciate it for your kind help.
