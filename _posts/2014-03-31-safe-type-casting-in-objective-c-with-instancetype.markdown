---
layout: post
title: "Safe Type Casting in Objective-C with 'instancetype'"
date: 2014-03-31 23:11
comments: true
categories: 
---
`instancetype` is a relative new keyword in Objective-C language. Besides its general usage scenarios, it can  be leveraged for safe casting. The approach is simply a category to `NSObject`:

```objective_c
@interface NSObject (OAUtils)
+ (instancetype)oa_cast:(id)any;
+ (instancetype)oa_cast:(id)any warnOnFailure:(BOOL)warnOnFailure;
@end

@implementation NSObject (OAUtils)
+ (instancetype)oa_cast:(id)any
{
    return [self oa_cast:any warnOnFailure:NO];
}

+ (instancetype)oa_cast:(id)any warnOnFailure:(BOOL)warnOnFailure
{
    if (any)
    {
        if ([any isKindOfClass:[self class]])
            return any;
        else if (warnOnFailure)
            NSLog(@"Can't cast %@ to type %@", any, NSStringFromClass([self class]));
    }
    
    return nil;
}
```

<!-- more -->

For example, it's common to store `NSNull` inside an `NSMutableArray` to indicate `nil` value actually. Then accessing the array normally requires extra type checking to insure `NSNull` is not used accidentally, which leads to crash at runtime. Using `oa_cast:` would make codes easier to write:

```objective_c
NSMutableArray * images = [NSMutableArray array];
[images addObject:[UIImage imageNamed:@"icon1.png"]];
[images addObject:[NSNull null]];
//...

UIImageView * secondImageView = ...;
secondImageView.image = [UIImage oa_cast:images[1]];
```

Happy coding!