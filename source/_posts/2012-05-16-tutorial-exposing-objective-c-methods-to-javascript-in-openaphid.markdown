---
layout: post
title: "Tutorial: Calling Objective-C Methods from JavaScript in OpenAphid"
date: 2012-05-16 10:06
comments: true
categories: 
---

[OpenAphid](https://github.com/openaphid) 0.2 was shipped with a new binding system which can bridge JavaScript functions to Objective-C methods on demand. It's useful for games to integrate analytics services, monetization solutions, and social services, etc. In this tutorial, we'll go through the binding system by demonstrating how to integrate [Google Analytics iOS SDK](https://developers.google.com/analytics/devguides/collection/ios/) into OpenAphid. 

<!-- more -->

## How to Access Objective-C Methods in JavaScript

The `OABindingProtocol` protocol, defined in [OABindingProtocol.h](https://github.com/openaphid/Runtime/blob/master/PreBuild/OABindingProtocol.h), defines a method `bindSelectors:` that you can implement in your Objective-C classes to expose their methods to the JavaScript environment. To make a method valid for export, its return type and all argument types must be the supported types below:

### Type Conversion of Return Value from Objective-C to JavaScript

<table class="aphid-table">
	<tr>
		<th>Objective-C</th>
		<th>JavaScript</th>
	</tr>
	<tr>
		<td>void</td> <td>undefined</td>
	</tr>
	<tr>
		<td>nil or NSNull</td> <td>null</td>
	</tr>
	<tr>
		<td>primitive numeric types<br/>(int, float, double, etc)</td> <td>number</td>
	</tr>
	<tr>
		<td>NSNumber</td> <td>number</td>
	</tr>
	<tr>
		<td>NSString</td> <td>string</td>
	</tr>
	<tr>
		<td>NSArray</td> <td>array</td>
	</tr>
	<tr>
		<td>NSDictionary</td> <td>object</td>
	</tr>
</table>

### Type Conversion of Argument Value from JavaScript to Objective-C

<table class="aphid-table">
	<tr>
		<th>JavaScript</th> <th>Objective-C</th>
	</tr>
	<tr>
		<td>undefined</td> <td>nil or NSNull</td>
	</tr>
	<tr>
		<td>null</td> <td>nil or NSNull</td>
	</tr>
	<tr>
		<td>number</td> <td>primitive number or NSNumber</td>
	</tr>
	<tr>
		<td>string</td> <td>NSString</td>
	</tr>
	<tr>
		<td>array</td> <td>NSArray</td>
	</tr>
	<tr>
		<td>object except array</td> <td>NSDictionary</td>
	</tr>
</table>

For any method to export, it must be explicitly declared in the implementation of `bindSelectors:` in your Objective-C class. For example, the snippet below exports `[DatastoreBinding saveString:]` to JavaScript environment as `int saveString(string)`:

```objective-c
#import "OABindingProtocol"
@interface DatastoreBinding : NSObject <OABindingProtocol>
@end

@implementation DatastoreBinding
- (BOOL) saveString:(NSString*)content
{
  [_myDatastore save:content];
}

#pragma OABindingProtocol
- (void) bindSelectors:(OABindingMap*)bindingMap
{
	[bindingMap bindSelector:@selector(saveString:) forName:@"saveString"];
}
@end
```

The binding object need be injected into JavaScript via `setScriptBinding:name:iOSOnly:` method of [OAGLViewController](https://github.com/openaphid/Runtime/blob/master/PreBuild/OAGLViewController.h):

```objective-c
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	//...
	[self.viewController.glViewController setScriptBinding:[[[DatastoreBinding alloc] init] autorelease] 
                                                    name:@"datastore" 
                                                 iOSOnly:YES
   ];
	//...
}
```

OpenAphid injects an instance of `DatastoreBinding` as a JavaScript object of `[object DynamicBinding]` into JavaScript environment. And its name is `datastore`. The `iOSOnly` argument manages the namespace which contains the injected object. If it's `YES`, then the injected object can be accessed via `aphid.extios.datastore`; otherwise it can be accessed via `aphid.ext.datastore`. 

> Notes: the `iOSOnly` argument is actually designed for future compliance when OpenAphid supports both iOS and Android.

## Integration with Google Analytics in Boilerplate-iOS

Let's see a more concrete example about integrating Google Analytics in [Boilerplate-iOS](https://github.com/openaphid/Boilerplate-iOS). 

After adding Google Analytics iOS SDK into the Xcode project by following its [official instructions](https://developers.google.com/analytics/devguides/collection/ios/devguide#gettingStarted). We create an Objective-C object to describe the binding in [OAGoogleAnalyticsBinding.h](https://github.com/openaphid/Boilerplate-iOS/blob/master/Boilerplate/Boilerplate/OAGoogleAnalyticsBinding.h):

```objective-c
@interface OAGoogleAnalyticsBinding : NSObject <OABindingProtocol>
@end
```

Then we add implementations of several methods in [OAGoogleAnalyticsBinding.m](https://github.com/openaphid/Boilerplate-iOS/blob/master/Boilerplate/Boilerplate/OAGoogleAnalyticsBinding.m) that we want to invoke in JavaScript:

```objective-c
@implementation OAGoogleAnalyticsBinding
//...

- (void) startTrackerWithAccountID:(NSString*)accountID despatchPeriod:(int)period
{
	[[GANTracker sharedTracker] startTrackerWithAccountID:accountID dispatchPeriod:period delegate:nil];
}

- (BOOL)trackPageview:(NSString *)pageURL
{
	return [[GANTracker sharedTracker] trackPageview:pageURL withError:NULL];
}

//...
```

The binding of the methods should be declared in the `bindSelectors:` method:

```objective-c
- (void)bindSelectors:(OABindingMap *)bindingMap
{
[bindingMap bindSelector:@selector(startTrackerWithAccountID:despatchPeriod:)
                 forName:@"startTracker"];

//...

[bindingMap bindSelector:@selector(trackPageview:)
                 forName:@"trackPageView"];
  
//...
}
```

Then we can inject it into JavaScript as following code inside [OAAppDelegate.m](https://github.com/openaphid/Boilerplate-iOS/blob/master/Boilerplate/Boilerplate/OAAppDelegate.m):

```objective-c
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	//...

	[self.viewController.glViewController setScriptBinding:[[OAGoogleAnalyticsBinding new] autorelease]  
                                                    name:@"gat" 
                                                 iOSOnly:NO];
	//...
}

```
> ** Updates at 07-09-2012: ** `iOSOnly` has been changed from `YES` to `NO` to match its Android version.

Now we can use Google Analytics in JavaScript to track the user's behavior in games:

```javascript
var gat = aphid.ext.gat; //Google Analytics is injected as aphid.ext.gat
gat.startTracker("UA-31741840-1", 10); //start a tracker
gat.trackPageView("main.js"); //track a page view
```
> ** Updates at 07-09-2012: ** Since `iOSOnly` has been set to `NO`, the JavaScript namespace for `gat` is switched to `aphid.ext` from `aphid.extios`

We're going to integrate more services into [Boilerplate-iOS](https://github.com/openaphid/Boilerplate-iOS), and make it be a better starter kit for game development with OpenAphid.

If you have better ideas, please feel free to contact us via `openaphid@gmail.com` or raise an issue in our [github repositories](https://github.com/openaphid). 
