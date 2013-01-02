---
layout: post
title: "FlipView for Android v0.9.7 Released"
date: 2013-01-02 14:26
comments: true
categories: 
---

[FlipView](https://github.com/openaphid/android-flip) v0.9.7 is released with various performance improvements and bug fixes.

Happy New Year 2013!

## Release Notes

<!-- more -->

For a complete change list please checkout our [issue tracker](https://github.com/openaphid/android-flip/issues/milestones?state=closed)

### [v0.9.7, Jan 1th 2012](https://github.com/openaphid/android-flip/issues?milestone=3&state=closed)

- The core control flow has been rewritten, which fixes several performance and reliability issues about adapter and async content support. ([#36](https://github.com/openaphid/android-flip/issues/36), [#29](https://github.com/openaphid/android-flip/issues/29), [#28](https://github.com/openaphid/android-flip/issues/28), [#8](https://github.com/openaphid/android-flip/issues/8))

- Supports different bitmap format for animation, which can be used to reduce peak memory consumption. ([#34](https://github.com/openaphid/android-flip/issues/34))

- Fixes a severe memory leak issue. ([#33](https://github.com/openaphid/android-flip/issues/33), [#21](https://github.com/openaphid/android-flip/issues/21))

- The demo [FlipAsyncContentActivity](https://github.com/openaphid/android-flip/blob/master/FlipView/Demo/src/com/aphidmobile/flip/demo/FlipAsyncContentActivity.java) has been rewritten to illustrate the correct way of handling async content. ([#37](https://github.com/openaphid/android-flip/issues/37))

- A new demo [FlipDynamicAdapterActivity](https://github.com/openaphid/android-flip/blob/master/FlipView/Demo/src/com/aphidmobile/flip/demo/FlipDynamicAdapterActivity.java) to demonstrate how to dynamically load more pages. ([#41](https://github.com/openaphid/android-flip/issues/41))

- Thanks to [@siegfriedpammer](https://github.com/siegfriedpammer) for his contribution. ([Pull #40](https://github.com/openaphid/android-flip/pull/40))