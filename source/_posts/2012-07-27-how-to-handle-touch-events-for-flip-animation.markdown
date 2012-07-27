---
layout: post
title: "How to Handle Touch Events in Flip Animation"
date: 2012-07-27 23:20
comments: true
categories: 
---

This short post explains how to handle touch events for the flip animation introduced in our [previous post](/blog/2012/05/21/how-to-implement-flipboard-animation-on-android/).

The full source codes of the demo application are available at Github:

[https://github.com/openaphid/android-flip/Demo-Touch/](https://github.com/openaphid/android-flip/Demo-Touch/)

A pre-built APK file is also present for your Android devices:

[https://github.com/openaphid/android-flip/Demo-Touch/APK/Flip-Touch.apk](https://github.com/openaphid/android-flip/Demo-Touch/APK/Flip-Touch.apk)

<!-- more -->

The new demo app adds two new features compared to the previous one:

- Supports flipping over between two views. [FlipCards.java](https://github.com/openaphid/android-flip/blob/master/Demo-Touch/src/com/aphidmobile/flip/FlipCards.java) takes screenshots of the front and back views, which are used to construct the textures for the translucent `GLSurfaceView`. The flip animation is rendered by four instances of [Card](https://github.com/openaphid/android-flip/blob/master/Demo-Touch/src/com/aphidmobile/flip/Card.java). Please refer to the [draw(GL10 gl)](https://github.com/openaphid/android-flip/blob/master/Demo-Touch/src/com/aphidmobile/flip/FlipCards.java) method for more details.

- Flip angle can be controlled by touch events. Angle is calculated according to the relative movement of touches. The logic can be found in the [handleTouchEvent(MotionEvent event)](https://github.com/openaphid/android-flip/blob/master/Demo-Touch/src/com/aphidmobile/flip/FlipCards.java) method.

## Future Enhancements

The demo app is just a prove of concept. It can be enhanced to be a component for general scenarios:

- To support a `Adapter` as its data source to load views dynamically and lazily.

- To implement similar APIs like `ListView`

- To support other fancy effects that can be implemented in OpenGL ES.

But I'm sorry that I'll be in a long trip with my family. Both `android-flip` and `OpenAphid` will not be updated until I come back. You can still reach me via email if you have any questions. 


