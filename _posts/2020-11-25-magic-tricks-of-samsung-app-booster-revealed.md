---
layout: post
title: '"Magic Trick" of Galaxy App Booster'
date: 2020-11-25 00:59 -0800
cover-img: "/assets/etc/app-booster.jpeg"
---

I happened to try an app called [Galaxy App Booster](https://galaxystore.samsung.com/prepost/000004665772?appId=com.samsung.android.appbooster) that is a part of [Galaxy Labs](https://galaxystore.samsung.com/prepost/000004665763?appId=com.android.samsung.utilityapp) released by Samsung. It claims that it can optimize all apps on device and boost the overall performance by 5% to 15%. It's attractive and many users are using it on non-Samsung phones too.

What kind of optimization does it use and how does it estimate the improvement? Does it just do a fake job and trick our mind? I decided to investigate the magic trick inside it.

# TLDR

App Booster runs profile-guided compilation on all apps immediately. It may make some apps run faster before they are optimized by the OS in idle maintenance mode, which means it could take a few days.

# Decompile

I fetched the [apk file](https://www.apkmirror.com/apk/samsung-electronics-co-ltd/app-booster/) from apkmirror, then used [jadx](https://github.com/skylot/jadx) to decompile it:

```
jadx -e -d booster app-booster.apk
```

Although it's obfuscated, I could load the code in Android Studio and manually rename the classes and methods of the main logic. It becomes easy to understand.

# Optimize Apps

When "Optimize Now" is tapped, it invokes `startCompileServices`:

```java
// HomeActivity

public void onClick(View view) {
    int id = view.getId();
    if (id == R.id.layout_optimize_now) {
        LoggingDI.get().a(R.string.screen_AppBooster_Page, R.string.event_RunOptimize, 0);
        this.homePresenter.startCompileServices(this.activityHomeBinding.only_optimize_app_recent_switch.isChecked());
    } else if (id == R.id.ll_switch) {
        this.activityHomeBinding.only_optimize_app_recent_switch.performClick();
    }
}
```

`startCompileServices` starts the compile service:

```java
public void startCompileServices(boolean z) {
    AppLog.info(this.g, "start Compile services");
    Intent intent = new Intent(this.ctx, OptimizeService.class);
    if (z) {
        intent.putStringArrayListExtra("list_package_compile", this.rencentUsedPackageNames);
        this.homeView.initCompilingAnimation(0, this.rencentUsedPackageNames.size());
    } else {
        intent.putStringArrayListExtra("list_package_compile", this.allPackageNames);
        this.homeView.initCompilingAnimation(0, this.allPackageNames.size());
    }
    this.ctx.startForegroundService(intent);
}
```

`OptimizeService` invokes `cmd package compile -m speed-profile` on each package:

```java
BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(Runtime.getRuntime().exec("cmd package compile -m speed-profile " + packageName).getInputStream()));
while (true) {
    String readLine = bufferedReader.readLine();
    if (readLine == null) {
        break;
    }
    if (readLine.equals("Success")) {
        OptimizeService.this.i.add(0, packageName);
    } else {
        AppLog.info("AppBoosterOptimizeService", "Compile package failed: " + packageName);
    }
    publishProgress(Integer.valueOf(i + 1));
}
```

The estimation of improvement is simple. It's set to 15% if a full optimization hasn't finished before. Otherwise, it's 5%.

```java
if (AppUtils.is_run_after_fota(this)) {
    this.approxBenefit = 5;
    this.approxTime    = 5;
} else {
    this.approxBenefit = 15;
    this.approxTime    = 15;
}
```

# More Explanation

Starting in Android 7.0, the Android Runtime (ART) uses a hybrid combination of ahead-of-time (AOT) compilation, just-in-time (JIT) compilation, and profile-guided compilation. The combination is configurable, and a typical mode uses the following flow as described in the [official document](https://source.android.com/devices/tech/dalvik/configure#how_art_works):

1. An application is initially installed without any AOT compilation. The first few times the application runs, it will be interpreted, and methods frequently executed will be JIT compiled.
2. When the device is idle and charging, a compilation daemon runs to AOT-compile frequently used code based on a profile generated during the first runs.
3. The next restart of an application will use the profile-guided code and avoid doing JIT compilation at runtime for methods already compiled. Methods that get JIT-compiled during the new runs will be added to the profile, which will then be picked up by the compilation daemon.

The command `cmd package compile -m speed-profile` used by App Booster tells the compiler tool `dex2oat` to immediately verify and AOT-compile methods listed in the profile file of an app, which is the same job of step 2. The speed difference is noticeable if step 2 has not been triggered as illustrated in a video I found on YouTube:

<iframe width="560" height="315" src="https://www.youtube.com/embed/bnRnNH68Acw" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

Profile-guided compilation is a powerful technology. Google Play even launched ["ART optimizing profiles in Play Cloud"](https://android-developers.googleblog.com/2019/04/improving-app-performance-with-art.html) last year, which runs the compilation on install or update by collecting profiles from the initial rollout of an app. It makes the benefit of App Booster less significant if the apps are downloaded from Google Play.