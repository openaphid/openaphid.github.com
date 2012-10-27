---
layout: post
title: "Aphid FlipView for Android v0.9 Beta Released"
date: 2012-09-21 15:11
comments: true
categories: 
---

I'm happy to announce the first release of [Aphid FlipView](https://github.com/openaphid/android-flip), an Android UI component which help add flipping animation in your application. Please download and install the pre-built demo APK file to check out it in action:

[https://github.com/openaphid/android-flip/tree/master/FlipView/Demo/APK](https://github.com/openaphid/android-flip/tree/master/FlipView/Demo/APK)

I'm also glad to use some pictures captured during my trip to build one of the demos:

![screenshot](/images/flipview-demo.gif "Screenshot of Aphid FlipView v0.9")

<!-- more -->


The work is derived from the previous demos as described in [post 1](/blog/2012/07/27/how-to-handle-touch-events-for-flip-animation/) and [post 2](http://openaphid.github.com/blog/2012/05/21/how-to-implement-flipboard-animation-on-android/). Besides the core animation effect, the v0.9 also fixes issues and adds features requested by several friends:

- `Adapter` is supported for adding multiple pages into a sequence of flipping animation.

- Touch events are correctly dispatched to views in each page, which allows using buttons or other controls in pages.

- Bouncing effect is added for the first and last pages.

- Less flicker when starting and ending the animation.

- Less CPU resource is used when the animation is idle.

## Core Classes

The component is released as an [Android Library Project](https://github.com/openaphid/android-flip/tree/master/FlipView/FlipLibrary). The core class is the [FlipViewController](https://github.com/openaphid/android-flip/blob/master/FlipView/FlipLibrary/src/com/aphidmobile/flip/FlipViewController.java).

The general routine of setting up `FlipViewController` is straightforward:

- Creates an instance of `FlipViewController`:

```java
	FlipViewController flipView = new FlipViewController(context);
```

- Provides an adapter as the data source. It's very similar to the setup logic for a `ListView`:

```java
		flipView.setAdapter(new BaseAdapter() {
			@Override
			public int getCount() {
				return count;
			}

			@Override
			public Object getItem(int position) {
				return position;
			}

			@Override
			public long getItemId(int position) {
				return position;
			}

			@Override
			public View getView(int position, View convertView, ViewGroup parent) {
				//setup a view by either reusing the convertView or creating a new one.				
				return view;
			}
		});
```

- Adds the instance of `FlipViewController` into your view hierarchy.

- Invokes `onPause` and `onResume` of `FlipViewController` correspondingly in your activity's life-cycle methods.

```java
	@Override
	protected void onResume() {
		super.onResume();
		flipView.onResume();
	}

	@Override
	protected void onPause() {
		super.onPause();
		flipView.onPause();
	}
```

Please also refer to the demo project for more details: 

[https://github.com/openaphid/android-flip/tree/master/FlipView/Demo](https://github.com/openaphid/android-flip/tree/master/FlipView/Demo)

## Important Notes

There are some facts about the component which you should pay special attention to:

- It's recommended to use only ONE instance per activity. As the animation is implemented in a `GLSurfaceView`, using multiple instances in one activity may cause serious compatible problems on some Android devices.

- Vertical scroll in sub-views may not work as the touch events are consumed by the animation.

- I don't have enough resources to test its compatibility across all Android OS versions and devices. Please verify it after integrating it in your project.

Please use [Github issues](https://github.com/openaphid/android-flip/issues) to report any problems and request more features. Thanks in advance.
