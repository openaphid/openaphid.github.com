---
layout: post
title: "Source Code Walkthrough of Telegram-iOS: Part 1"
subtitle: ""
tags: [Telegram, iOS]
comments: true
---

![Cover](/assets/tg-ios/part-1-cover.png)

# Introduction

Telegram is one of the most popular instant messengers in the market. As of April this year, its MAU has passed [400 million](https://telegram.org/blog/400-million). It’s a great achievement considering its service is not available in [some countries](https://en.wikipedia.org/wiki/Telegram_(software)#Censorship).

Most Telegram [client apps](https://telegram.org/apps) are open-sourced to prove its gene of security. They also started [a new process](https://core.telegram.org/reproducible-builds) to allow others to verify the iOS and Android source code is the same version that’s used on AppStore and Google Play. The process is an appreciated move that helps ease the criticism over its [slow release habit](https://news.ycombinator.com/item?id=18837699) in the past years.

As iOS is my favorite platform, the first series of articles is all about [Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS). The codebase shows its solutions to many practical engineering problems that other iOS engineers would encounter, such as reliable network, secure storage, reactive events, multimedia playback, interactive UX, complex list UI, customization/hacks to system controllers, etc.

# Overview of the Code

Telegram-iOS organizes the source code by over 200 [submodules](https://github.com/TelegramMessenger/Telegram-iOS/tree/master/submodules) with more than two million lines of code. I roughly put these modules into five categories:

- `App`, modules that support the main app features, like foundation utils, UI, network, etc.
- `VoIP`, the feature of voice calls which was released at the end of March 2017.
- `Watch`, the Watch app.
- `TON`, the experimental integration with the new blockchain platform.
- `3rd-party`, the other open-source projects it depends on.

Below is the LOC statistic of each category:

<iframe id="datawrapper-chart-GgwGN" src="https://datawrapper.dwcdn.net/GgwGN/2/" scrolling="no" frameborder="0" style="width: 0; min-width: 100% !important; border: none;" height="408"></iframe>
<script type="text/javascript">!function(){"use strict";window.addEventListener("message",(function(a){if(void 0!==a.data["datawrapper-height"])for(var e in a.data["datawrapper-height"]){var t=document.getElementById("datawrapper-chart-"+e)||document.querySelector("iframe[src*='"+e+"']");t&&(t.style.height=a.data["datawrapper-height"][e]+"px")}}))}();
</script>

Telegram-iOS is a mixed language project. By looking into the `App` category, there are nearly 70% code in Swift and 24% in Objective-C/C++. [Buck](https://buck.build/) is used as the build tool. It seems it’s moving to [Bazel](https://bazel.build/) as well. For readers who are not familiar with the iOS build tools, the normal Xcode project file format, like `.xcodeproj` and `.xcworkspace`, is good enough for smaller projects. It would become difficult to maintain in the long run as the files are represented in XML and edited via Xcode UI instructions. It’s usually not a pleasant experience when there are merge conflicts inside Xcode files, and it’s challenging to spot issues during code review.

Buck is a build system developed by Facebook. It encourages small modules consisting of code and resources, which results in clean build config files and faster parallel build. For a typical module, it simply has a `BUCK` file to describe the build rules in a dozen lines, a `Sources` folder for the code files, and an optional `Resouces` folder for images. The command `buck project` can generate the Xcode project files for engineers to develop in Xcode, and these files are explicitly ignored in Git. You can find more details in the [`Makefile`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/Makefile#L382). There is also a [template project](https://github.com/airbnb/BuckSample) from Airbnb to build iOS applications using Buck.

# Submodules

Here is a list of stats for all 229 submodules. 136 modules consist of no more than two source files with a few hundreds of lines. Some small ones don’t deserve to be in dedicated modules and might be merged IMO, but it’s a matter of design taste.

 <iframe class="google-docs" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vQaISv-fxcPuMVE6stlH5xU91fj7rRE4jYd2gxJwwKctTWWtosm3CHqM8dHjnYq1QuZ41TduSN5sqOx/pubhtml?widget=true&amp;headers=false" frameborder="0" allowfullscreen="true" mozallowfullscreen="true" webkitallowfullscreen="true"></iframe>

# Conclusion

The code statistics should give a brief impression on the Telegram-iOS project. I’ll talk about the foundation modules in the next post.