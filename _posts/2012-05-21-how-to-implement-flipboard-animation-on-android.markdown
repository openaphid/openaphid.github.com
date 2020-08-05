---
layout: post
title: "How to Implement Flipboard Animation on Android"
date: 2012-05-21 22:14
comments: true
categories: [FlipView]
---

> ** Updates at 2012-12-12: ** Please check out [FlipView](/blog/categories/flipview/) for an improved solution.

The demo in this post was born when we're working on the Android port of [OpenAphid-Engine](https://github.com/openaphid). One of our engineers is a huge fan of [Flipboard iOS](http://www.flipboard.com). He decided to implement its page flip animation on Android. 

If you don't know about the effect, please install the APK file of our demo app to see how it looks:
<!-- more -->

[http://openaphid.github.com/images/AndroidFlip.apk](http://openaphid.github.com/images/AndroidFlip.apk)

The full source codes of the demo application is also available at Github:

[https://github.com/openaphid/android-flip](https://github.com/openaphid/android-flip)

## Overview

The Flipboard animation is easy to achieve on iOS by using Core Animation. Things get a bit difficult on Android:

- The view animation framework on Android is not flexible and efficient for versions prior to 3.0;

- The Android layout system makes it even harder for advanced animation;

In order to apply flip effect for views with arbitrary structures and make the animation run smoothly, several tricks are used in our approach. OpenGL ES is used to render the animation for efficiency; a special view container is implemented to grab content of a view to OpenGL ES. Let's go through them one by one.

## View Hierarchy

Our demo app displays two LinearLayouts at the same time: [R.layout.first_page](https://github.com/openaphid/android-flip/blob/master/res/layout/first_page.xml) and [R.layout.second_page](https://github.com/openaphid/android-flip/blob/master/res/layout/second_page.xml).

![first_page](/images/flip-first-page.jpg)
![second_page](/images/flip-second-page.jpg)

The first page is displayed over the second page. We took a screenshot when the first page flipped by 75 degrees:

![flip-75-degree](/images/flip-75-degree.jpg)

When the first page is flipping, its top half stays still while the bottom half flips around the horizontal center axis of the page; part of the second page is visible during the animation.

## Custom ViewGroup

A custom `ViewGroup`, [FlipViewGroup](https://github.com/openaphid/android-flip/blob/master/src/com/aphidmobile/flip/FlipViewGroup.java), is used to manage the visibility of the two pages and serve content to OpenGL ES. Besides using a `LinkedList` to manage normal sub-views, it also contains a `GLSurfaceView` to play animation:

```java
private LinkedList<View> flipViews = new LinkedList<View>();
private GLSurfaceView surfaceView;
```

The GLSurfaceView is added as a sub-view automatically. The `onLayout` method of `FlipViewGroup` is overridden to monitor the changes of view dimension:

```java
		for (View child : flipViews)
			child.layout(0, 0, r - l, b - t);

		if (changed) {
			int w = r - l;
			int h = b - t;
			surfaceView.layout(0, 0, w, h);
			
			if (width != w || height != h) {
				width = w;
				height = h;

				if (flipping && !flipViews.isEmpty()) {
					View view = flipViews.getLast(); 
					renderer.updateTexture(view);
					view.setVisibility(View.INVISIBLE);
				}
			}
		}
```

As in line 14 to line 16, when a change of view dimension is detected and flipping is on, the OpenGL render updates the texture by taking a screenshot of the top view; then the top view is hidden while the `GLSurfaceView` will display its content with flip animation.

## GrabIt

[GrabIt](https://github.com/openaphid/android-flip/blob/master/src/com/aphidmobile/flip/GrabIt.java) is a small utility to convert the content of a view to a `Bitmap`. The result bitmap will be used to construct the texture for `GLSurfaceView`.

## Setup of GLSurfaceView and Renderer

The `GLSurfaceView` instance is setup to use the following configurations:

- A RGBA_8888 surface with 16-bit depth buffer;
- It's displayed on the top of the window;
- A custom renderer: `FlipRenderer`;
- The desired PixelFormat of the surface should support translucency;
- The rendering mode is set to make the renderer be called repeatedly;

The [FlipRenderer](https://github.com/openaphid/android-flip/blob/master/src/com/aphidmobile/flip/FlipRenderer.java) maps the OpenGL pixels to 2D screen pixels one-by-one which is similar to what OpenAphid-Engine does for 2D games. And the origin of the coordinate system is bottom left.

The actual drawing process is managed in the instance of `FlipCards`.

## FlipCards

[FlipCards](https://github.com/openaphid/android-flip/blob/master/src/com/aphidmobile/flip/FlipCards.java) manages the content and structure of flip animation. It accepts a bitmap, which should be the screenshot of the first page, to build the texture for rendering. The texture is binded to two instances of `Card` object. `topCard` renders the top half, which stays still; `bottomCard` draws the flipping effect of the bottom half.

## Card

[Card](https://github.com/openaphid/android-flip/blob/master/src/com/aphidmobile/flip/Card.java) represents a quadrilateral in OpenGL space. Its `angle` property controls the flip angle, which is accomplished by the following OpenGL codes:

```java
		if (angle > 0) {
			gl.glTranslatef(0, cardVertices[1], 0f);
			gl.glRotatef(-angle, 1f, 0f, 0f);
			gl.glTranslatef(0, -cardVertices[1], 0f);
		}
```

A `Card` instance also takes a texture to bind to it. Let's take the `topCard` of `FlipCards` for example:

```java
			topCard.setTexture(texture);
		
			topCard.setCardVertices(new float[]{
				0f, bitmap.getHeight(), 0f,                     //top left
				0f, bitmap.getHeight() / 2.0f, 0f,              //bottom left
				bitmap.getWidth(), bitmap.getHeight() / 2f, 0f, //bottom right
				bitmap.getWidth(), bitmap.getHeight(), 0f       //top right
			});

			topCard.setTextureCoordinates(new float[]{
				0f, 0f,
				0, bitmap.getHeight() / 2f / (float) texture.getHeight(),
				bitmap.getWidth() / (float) texture.getWidth(), bitmap.getHeight() / 2f / (float) texture.getHeight(),
				bitmap.getWidth() / (float) texture.getWidth(), 0f
			});
```

The vertices of `topCard` are set to make the card at the top half of the application screen. And its texture coordinates are set to render the top half of the first page.

In order to make the flip effect more realistic, a gray rectangle is rendered to cover the appealed area of the second page, which looks like a shadow of the flipping card casting on the second page.

```java
		if (angle > 0) {
			gl.glDisable(GL_LIGHTING);
			gl.glDisable(GL_DEPTH_TEST);
			float w = cardVertices[9] - cardVertices[0];	//shadow width
			float h = (cardVertices[1] - cardVertices[4]) * (1f - FloatMath.cos(d2r(angle))); //shadow height
			float z = (cardVertices[1] - cardVertices[4]) * FloatMath.sin(d2r(angle));	//z index of the top side of shadow
			float[] shadowVertices = new float[]{
				cardVertices[0], h + cardVertices[4], z,
				cardVertices[3], cardVertices[4], 0f,
				w, cardVertices[7], 0f,
				w, h + cardVertices[4], z
			};

			float alpha = 1f * (90f - angle) / 90f;	//shadow alpha

			gl.glColor4f(0f, 0.0f, 0f, alpha);
			gl.glVertexPointer(3, GL_FLOAT, 0, toFloatBuffer(shadowVertices));
			gl.glDrawElements(GL_TRIANGLES, indices.length, GL_UNSIGNED_SHORT, indexBuffer);
			gl.glEnable(GL_DEPTH_TEST);
			gl.glEnable(GL_LIGHTING);
		}
```

The snippets above should cover the core concepts of our approach. You can fork the project to support more effects as we can see in Flipboard iPhone, like page flip following touch moves, flip over of a page, and book flip effect etc. 

BTW, we're tackling some technical problems of OpenAphid-Engine Android version. Will keep you posted if a stable version is ready.
