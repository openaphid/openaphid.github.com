---
layout: post
title: "Tutorial: Exposing Java Methods to JavaScript in OpenAphid"
date: 2012-07-10 14:39
comments: true
categories: 
---

[OpenAphid](https://github.com/openaphid) for Android v0.1.5 supports exposing Java methods as JavaScript functions, which is helpful for integrating 3rd-party services into games. The binding APIs are similar to its [iOS version](/blog/2012/05/16/tutorial-exposing-objective-c-methods-to-javascript-in-openaphid/).

<!-- more -->

## How to Expose Java Methods to JavaScript

Any public Java methods with supported return type and parameter types, can be exposed as JavaScript functions via [@AphidJSFunction](https://github.com/openaphid/Runtime/blob/master/PreBuild/Android/src/org/openaphid/bind/AphidJSFunction.java) annotation. An instance with exposed methods can be injected into JavaScript engine as a plain JavaScript object by using [AphidRenderer.setScriptBinding(String name, Object bindingObject, boolean androidOnly)](https://github.com/openaphid/Runtime/blob/master/PreBuild/Android/src/org/openaphid/gl/AphidRenderer.java). The injected object will be placed inside `aphid.ext` or `aphid.extandroid` namespaces, which is managed by the `androidOnly` parameter.

### Example of @AphidJSFunction

```java
public class BindingTest4 {	
	@AphidJSFunction(name="add", isInUIThread=true)
	public int addInMainThread(int i1, int i2) {
		UI.assertInMainThread();
		return i1 + i2;
	}
}

//in onCreate() method of AphidActivity
glSurfaceView.getAphidRenderer().setScriptBinding("test4", new BindingTest4(), false);
```

The snippet above injects an instance of Java class `BindingTest4` to JavaScript as `aphid.ext.test4`. Its method `addInMainThread()` can be accessed via `aphid.ext.test4.add()` in JavaScript.

The `AphidJSFunction` annotation supports two optional element-value pairs: `name` and `isInUIThread`. `name` declares a custom function name to JavaScript, the Java method name is used if it's not specified; `isInUIThread` controls the thread to invoke the Java method, its default value is `false`. In OpenAphid for Android, JavaScript runs inside the GL thread. Setting `isInUIThread` to `true` makes the Java method run inside the UI thread; the execution of JavaScript is blocked in the GL thread until the Java method returns from the UI thread.

### Type Conversion of Return Value from Java to JavaScript

<table class="aphid-table">
	<tr>
		<th>Java</th>
		<th>JavaScript</th>
	</tr>
	<tr>
		<td>void</td> <td>undefined</td>
	</tr>
	<tr>
		<td>null</td> <td>null</td>
	</tr>
	<tr>
		<td>boolean</td> <td>bool</td>
	</tr>
	<tr>
		<td>primitive numeric types<br/>(short, char, int, long, float, double)</td> <td>number</td>
	</tr>
	<tr>
		<td>String</td> <td>string</td>
	</tr>
	<tr>
		<td>List</td> <td>array</td>
	</tr>
	<tr>
		<td>Map</td> <td>object</td>
	</tr>
</table>

### Type Conversion of Parameter Value from JavaScript to Java

<table class="aphid-table">
	<tr>
		<th>JavaScript</th> <th>Java</th>
	</tr>
	<tr>
		<td>undefined</td> <td>null</td>
	</tr>
	<tr>
		<td>null</td> <td>null</td>
	</tr>
	<tr>
		<td>number</td> <td>corresponding primitive numeric type</td>
	</tr>
	<tr>
		<td>string</td> <td>String</td>
	</tr>
	<tr>
		<td>array</td> <td>List</td>
	</tr>
	<tr>
		<td>object except array</td> <td>Map</td>
	</tr>
</table>

Strict type checking is performed during conversion, which throws a JavaScript exception if the types are mismatched.

## Integration with Google Analytics in Boilerplate-Android

Let's illustrate how to integrate Google Analytics SDK into OpenAphid for Android. All source codes can be found in the [Boilerplate-Android](https://github.com/openaphid/Boilerplate-Android) project.

After adding Google Analytics Android SDK into our project as described in its [official document](https://developers.google.com/analytics/devguides/collection/android/devguide#gettingStarted), we create a Java class [GoogleAnalyticsBinding](https://github.com/openaphid/Boilerplate-Android/blob/master/src/org/openaphid/thirdparty/ga/GoogleAnalyticsBinding.java) to bridge JavaScript and Google Analytics SDK. `GoogleAnalyticsBinding` makes the exposed functions have identical signatures as its iOS version, which enables the same script file([main.js](https://github.com/openaphid/Boilerplate-iOS/blob/master/Boilerplate/game.bundle/main.js)) to run on both platforms.

```java
public class GoogleAnalyticsBinding {
	//...

	@AphidJSFunction(isInUIThread = true, name = "setCustomVariableForScope")
	public void setCustomVariable(int index, String name, String value, int scope) {
		GoogleAnalyticsTracker.getInstance()
				.setCustomVar(index, name, value, scope);
	}

	//...
}
```

Then we can inject an instance into JavaScript namespace `aphid.ext` as what we do in iOS version:

```java
glSurfaceView.getAphidRenderer().setScriptBinding(
	"gat", 
	new GoogleAnalyticsBinding(), 
	false	//place inside aphid.ext namespace
	);
```

Now all Google Analytics APIs can be accessed by the same JavaScript functions inside `aphid.ext.gat` on both iOS and Android.

That's all for this tutorial. We're working on OpenAphid for Android v0.2, which implements `XMLHttpRequest` APIs as what we already have in iOS version.
