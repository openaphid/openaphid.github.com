---
layout: post
title: "Tutorial: Developer Mode of OpenAphid"
date: 2012-05-02 14:52
comments: true
categories: [Tutorial, iOS]
---

`Developer Mode` is a feature to speed up developing games with OpenAphid. The behavior of OpenAphid changes if the developer mode is turned on.

<!-- more -->

## How to Enable Developer Mode?

Open your project with Xcode and locate the following lines in `OAAppDelegate.m`:

``` objective-c
[self.viewController.glViewController configBundleName:@"game.bundle" 
                                               baseURL:[NSURL URLWithString:@"http://129.158.217.36:18080"]
                                           developMode:YES];
```

1. Setting the value of the `developMode` parameter to `YES` enables the developer mode of OpenAphid;

2. An HTTP server should be used to host the content inside the bundle folder specified by `configBundleName`. The value for the `baseURL` parameter should be set to the server address too. A ruby based tiny HTTP server is included in our boilerplate project, please refer to the `web_server.rb` and `start_dev_server.sh` files for more details;

3. The application should be built and re-deployed to devices with the new settings.

And for the [Boilerplate-iOS](https://github.com/openaphid/Boilerplate-iOS) project, `UIApplicationExitsOnSuspend` is `YES` in its info.plist file; which makes the app terminate automatically when the Home button is pressed.

## Changes in Developer Mode

The main benefit of using developer mode is that it makes the game development speedy like developing for web:

- JavaScript files are fetched from the HTTP server. If you want to see the result of your changes in the game script, you only need to re-open the app;

- Graphics resources are fetched remotely too. For example, a texture can be created by using `new aphid.g2d.Texture2D("player.png")`; the `player.png` file is fetched via `http://129.158.217.36:18080/player.png` in developer mode. OpenAphid Runtime also prints a log about it as following:

```
INFO 05/02/12,13:41:32: (developer mode) loading data 'player.png' from remote: http://129.158.217.36:18080/player.png
```

- Internal warning and error messages are displayed as on-screen notifications besides logging in device console. Warning messages are in blue background color and errors are in red color. The screenshot below shows a notification about a syntax error at line 17 in main.js:

![Error Notification](/images/developer-mode-error-notification.png "Notification")

- Messages produced by `console.warn` and `console.error` are also displayed as notifications;

- Write access to read-only attributes of OpenAphid objects throws exception in developer mode.

With the developer mode of OpenAphid, the typical development process is as follows:

1. Developer edits the JavaScript file with game logics and updates graphic files inside the bundle folder;

2. Presses the home button and enters the app again to see the result of the changes;

3. Following the on-screen notifications and console logs to diagnose mistakes in JavaScript files.

Hope you like the developer mode of OpenAphid. We'll improve it constantly to make game development easier. Please feel free to contact us if you have any suggestions.