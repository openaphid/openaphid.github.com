---
layout: post
title: "Tutorial: Handling Touch Events in OpenAphid-Engine v0.1.1"
date: 2012-05-06 21:54
comments: true
categories: [OpenAphid-Engine, Tutorial]
---

We are glad to release OpenAphid-Engine v0.1.1, which adds multitouch support and fixes several issues about touch handling. The detailed change log is following:

<!-- more -->

- Supports multitouch events: adds `multipleTouchEnabled` attribute to `Director` 
- Adds `userInteractionEnabled` attribute to Node
- Fixes incorrect values of `event.touches` and `event.targetTouches` in `ontouchend` callback
- Adds a new constructor function to Color: `new Color(color, [alpha])` 

## Basics of Touch Event Handling

Any instances of the `Node` class can be the `EventTarget` of touch events in OpenAphid-Engine. This is different from [cocos2d-iphone](http://www.cocos2d-iphone.org/), in which `CCLayer` is usually the target of touch event.

Several attributes affect how a node handles touch events: `multipleTouchEnabled` of the `Director` class; `userInteractionEnabled`, `visible`, `touchEnabled`, and `contentSize` of the `Node` class.

## Flow of Touch Event

The flow of a touch event goes through 2 phases: hit-testing and event bubbling.

### Hit-Testing

When a touch happens on the device screen, OpenAphid-Engine follows the routine below to locate its event target:

1. Hit-testing is used to find the sub-node of the running scene that is under a touch. This method proceeds recursively on each node in the node hierarchy.

2. Hit-testing fails on a node and doesn't proceed on its children if either `userInteractionEnabled` or `visible` is `false`.

3. The testing fails on a node but proceeds on its children if its `touchEnabled` is `false`

4. If the `contentSize` if a node is zero, hit-testing is delegated to its children nodes; otherwise it proceeds when the touch took place inside the rectangle area defined by the `contentSize`.

5. A node becomes the event target when it meets the following conditions: its `contentSize` is not zero and the touch location is inside it; hit-testing fails on any of its children but succeeds on it.

### Event Bubbling

Once the event target of a touch is found by hit-testing, a touch event object is passed to its callback functions, and bubbling up to its ancestors of which `touchEnabled` is `true`. `event.stopPropagation` can be used to stop bubbling.

## Interfaces of Touch Event

The APIs of touch event handling in OpenAphid-Engine are implemented to follow the specification of [W3C DOM Touch Event Version 1](http://www.w3.org/TR/touch-events/). There are already lots of guides about handling touches in DOM, which can be used as references for OpenAphid-Engine too. We've updated the [Demos](https://github.com/openaphid/Demos) of OpenAphid-Engine to include a `TouchTest` application, which demonstrates three scenarios of touch handling:

- Handling a single touch event to drag a sprite.

- Handling multitouch events to move multiple sprites.

- Detecting pinch gesture to zoom in/out a sprite.

Please checkout the [Demos](https://github.com/openaphid/Demos) project for more details. We're also going to implement gesture detection APIs in the future.