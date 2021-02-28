---
layout: post
title: "Source Code Walkthrough of Telegram-iOS Part 5: AsyncDisplayKit"
subtitle: ""
cover-img: "/assets/tg-ios/part-5-cover.png"
tags: [Telegram, iOS]
comments: true
---

Telegram-iOS builds most UIs upon AsyncDisplayKit. It’s folked as a [submodule](https://github.com/TelegramMessenger/Telegram-iOS/tree/release-6.1.2/submodules/AsyncDisplayKit) of the project, in which many features have been removed and some of them are re-implemented in Swift. This post talks about the component structure and the UI programming pattern in the project.

# 1. Overview

AsyncDisplayKit is an asynchronous UI framework that was originally [born from Facebook](https://engineering.fb.com/ios/introducing-asyncdisplaykit-for-smooth-and-responsive-apps-on-ios/). It’s [adopted by Pinterest](https://medium.com/pinterest-engineering/introducing-texture-a-new-home-for-asyncdisplaykit-e7c003308f50) and was renamed to [Texture](https://texturegroup.org/) in 2017. Its core concept is using [`node`](https://texturegroup.org/docs/getting-started.html) as an abstraction of `UIView`, which is a bit similar to the ideas from React Virtual DOM. Nodes are thread-safe, which helps move expensive UI operations off the main thread, like image decoding, text sizing, etc. Nodes are also lightweight, which allows you to [NOT reuse cells](https://texturegroup.org/docs/faq.html#ascellnode-reusability) in tables and collections.

![AsyncDisplayKit](/assets/tg-ios/part-5-asyncdisplaykit.png "Structure of the folked AsyncDisplayKit"){: .fit-img :}

As illustrated in the diagram, Telegram-iOS keeps around 35% code that’s denoted in blue boxes and removes the others from the official version.

- The latest commit that’s merged from upstream is [`ae2b3af9`](https://github.com/TextureGroup/Texture/commit/ae2b3af9).
- The fundamental nodes like [`ASDisplayNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/AsyncDisplayKit/Source/ASDisplayNode.mm), [`ASControlNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/AsyncDisplayKit/Source/ASControlNode.mm), [`ASEditableTextNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/AsyncDisplayKit/Source/ASEditableTextNode.mm), and [`ASScrollNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/AsyncDisplayKit/Source/ASScrollNode.mm) are mostly intact.
- [`ASImageNode`](https://texturegroup.org/docs/image-node.html) and its subclasses are removed. Telegram uses MTProto instead of HTTPS to download files from data centers. The [network image support](https://texturegroup.org/docs/network-image-node.html) from the official version is not useful, so the dependency on [`PINRemoteImage`](https://github.com/pinterest/PINRemoteImage) is deleted too.
- All official [node containers](https://texturegroup.org/docs/containers-overview.html) are removed, such as [`ASCollectionNode`](https://texturegroup.org/docs/containers-ascollectionnode.html), [`ASTableNode`](https://texturegroup.org/docs/containers-astablenode.html), [`ASViewController`](https://texturegroup.org/docs/containers-asviewcontroller.html), etc. Tables and view controllers on nodes are re-implemented in Swift without depending on [`IGListKit`](https://github.com/TextureGroup/Texture/blob/master/Source/Layout/ASLayout%2BIGListDiffKit.h).
- The project prefers manual layout. The [official layout API inspired by CSS Flexbox](https://texturegroup.org/docs/layout2-quickstart.html) is removed, so is the [yoga engine](https://texturegroup.org/development/layout-specs.html).
- The internal [logging and debugging](https://texturegroup.org/development/how-to-debug.html) supports are removed.

Basically speaking, Telegram-iOS keeps a minimal set of the core node system and then extends it with several hundreds of node subclasses. The code spreads inside submodules like [`Display`](https://github.com/TelegramMessenger/Telegram-iOS/tree/release-6.1.2/submodules/Display), [`TelegramUI`](https://github.com/TelegramMessenger/Telegram-iOS/tree/release-6.1.2/submodules/TelegramUI), [`ItemListUI`](https://github.com/TelegramMessenger/Telegram-iOS/tree/release-6.1.2/submodules/ItemListUI) and others that support the main Telegram UI features.

# 2. Core Nodes

![Core Nodes](/assets/tg-ios/part-5-corenodes.png "Core Node Classes"){: .fit-img :}

There are a few node classes as fundamental blocks to build the app’s user interface. Let’s check them out as listed in the diagram.

{: .box-note}
An arrowed edge means the right node is a subclass of the left one. Nodes at the same level without edges means they share the same parent class as the leftmost one.

## Text

[`TextNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/TextNode.swift#L775), [`ImmediateTextNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/ImmediateTextNode.swift#L9), and [`ASTextNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/ImmediateTextNode.swift#L199) are responsible for text rendering.

```swift
public class TextNode: ASDisplayNode {
    public internal(set) var cachedLayout: TextNodeLayout?
    
    public static func asyncLayout(_ maybeNode: TextNode?) -> (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode)
}

public class ImmediateTextNode: TextNode {
    public var attributedText: NSAttributedString?
    public var textAlignment: NSTextAlignment = .natural
    public var truncationType: CTLineTruncationType = .end
    public var maximumNumberOfLines: Int = 1
    public var lineSpacing: CGFloat = 0.0
    public var insets: UIEdgeInsets = UIEdgeInsets()
    public var textShadowColor: UIColor?
    public var textStroke: (UIColor, CGFloat)?
    public var cutout: TextNodeCutout?
    public var truncationMode: NSLineBreakMode
    public var linkHighlightColor: UIColor?
    public var trailingLineWidth: CGFloat?
    public var highlightAttributeAction: (([NSAttributedString.Key: Any]) -> NSAttributedString.Key?)?
    public var tapAttributeAction: (([NSAttributedString.Key: Any], Int) -> Void)?
    public var longTapAttributeAction: (([NSAttributedString.Key: Any], Int) -> Void)?
    ...
}

public class ASTextNode: ImmediateTextNode {
    override public var attributedText: NSAttributedString? {
        didSet {
            self.setNeedsLayout()
        }
    }
    ...
}
```

`TextNode` leverages `CoreText` to render an `NSAttributedString`. It has a method [`calculateLayout`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/TextNode.swift#L826) to compute a line based text layout and overrides the class method [`draw`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/TextNode.swift#L1084) to render the text. A public class method [`asyncLayout`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/TextNode.swift#L1198) is present to invoke layout computation asynchronously and cache the result. It’s the callee’s responsibility to invoke `asyncLayout` by design. Otherwise, it wouldn’t render anything as the cached layout is nil. It’s also great that the implementation supports [RTL](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/TextNode.swift#L32) and [Accessibility](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/TextNode.swift#L668).

`ImmediateTextNode` enriches `TextNode` by adding more properties to control the text layout styles. It also supports link highlighting and tap actions.

`ASTextNode` simply updates the layout on setting the property `attributedText`. It’s not the [same one](https://texturegroup.org/docs/text-node.html) in AsyncDisplayKit project although it shares the same class name.

[`EditableTextNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/EditableTextNode.swift#L5) extends `ASEditableTextNode` to support RTL input detection.

## Image

```swift
open class ASImageNode: ASDisplayNode {
    public var image: UIImage?
}

public class ImageNode: ASDisplayNode {
    public func setSignal(_ signal: Signal<UIImage?, NoError>)
}

open class TransformImageNode: ASDisplayNode {
    public var imageUpdated: ((UIImage?) -> Void)?
    public var contentAnimations: TransformImageNodeContentAnimations = []
    
    public func setSignal(_ signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>, attemptSynchronously: Bool = false, dispatchOnDisplayLink: Bool = true)
    public func setOverlayColor(_ color: UIColor?, animated: Bool)
}
```

[`ASImageNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/Nodes/ASImageNode.swift#L5) renders a `UIImage` and uses the image size as its node size. Again it’s not the [same class](https://texturegroup.org/docs/image-node.html) in the official project.

[`ImageNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/ImageNode.swift#L124) accepts a Signal to set the image content asynchronously. It’s solely used by [`AvatarNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/AvatarNode/Sources/AvatarNode.swift#L216) although its name looks common.

[`TransformImageNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/176e4eaad7505b12c86a400b9da6903695b3bc35/submodules/Display/Source/TransformImageNode.swift#L17) is the most widely used class for asynchronous images. It supports an alpha animation on changing images and supports color overlay.

## Button

```swift
open class ASButtonNode: ASControlNode {
    public let titleNode: ImmediateTextNode
    public let highlightedTitleNode: ImmediateTextNode
    public let disabledTitleNode: ImmediateTextNode
    public let imageNode: ASImageNode
    public let disabledImageNode: ASImageNode
    public let backgroundImageNode: ASImageNode
    public let highlightedBackgroundImageNode: ASImageNode
}

open class HighlightTrackingButtonNode: ASButtonNode {
    public var highligthedChanged: (Bool) -> Void = { _ in }
}

open class HighlightableButtonNode: HighlightTrackingButtonNode {
    ...
}
```

[`ASButtonNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/Nodes/ButtonNode.swift#L5) models a button with an image and a title that have three states: normal, highlighted, and disabled.

[`HighlightableButtonNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/HighlightableButton.swift#L87) adds a highlight animation when a button is in tracking.

## Status

[`ActivityIndicator`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/ActivityIndicator/Sources/ActivityIndicator.swift#L57) replicates the style of `UIActivityIndicatorView` and provides flexible options to customize details like [color, diameter, and line width](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/ActivityIndicator/Sources/ActivityIndicator.swift#L64).

## Media

Telegram-iOS implements a rich set of components to support different media types. This article just takes a peek at it. It’s worth writing a dedicated post in this series, including FFMpeg integration, in-app video playback for 3rd-party video sites, sticker animation, etc.

[`MediaPlayNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MediaPlayer/Sources/MediaPlayerNode.swift#L54) is a node class in the submodule [`MediaPlayer`](https://github.com/TelegramMessenger/Telegram-iOS/tree/release-6.1.2/submodules/MediaPlayer) to render video frames on `AVSampleBufferDisplayLayer`.

[`WebEmbedPlayerNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUniversalVideoContent/Sources/WebEmbedPlayerNode.swift#L63) plays a video that's inside a web page by embedding a `WKWebView`. It supports videos from Youtube, Vimeo, Twitch, etc.

[`AnimatedStickerNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/AnimatedStickerNode/Sources/AnimatedStickerNode.swift#L385) plays the gorgeous animation from an `AnimatedStickerNodeSource`.

## Bar

[`SearchBarNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/SearchBarNode/Sources/SearchBarNode.swift#L253), [`NavigationBar`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/NavigationBar.swift#L105), [`TabBarNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/TabBarNode.swift#L303), and [`ToolbarNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/ToolbarNode.swift#L5) mimic the features of the UIKit counterparts. It also eliminates the impact of the inconsistent behavior across OS versions, which is always an unpleasant issue to patch as UIKit internals are not visible to developers.

[`StatusBar`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/StatusBar.swift#L66) shows an in-call text notice in the system status bar area.

## List

[`ListView`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/ListView.swift#L134) is one of the most complex node classes designed for a scrolling list. It leverages a hidden `UIScrollView` and borrows its pan gesture to get the scrolling behavior as what we learned from [WWDC 2014](https://asciiwwdc.com/2014/sessions/235). Besides managing the visibility of items in a list no matter it’s small or huge, it provides additional neat features, such as convenient item headers, customizable scroll indicators, recording items, over scroll nodes, snapping to bounds, etc.

[`GridNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/GridNode.swift#L208) is another scrolling UI component for grid layout. It supports features like sticker selection screen, wallpaper settings, etc.

# 3. Controllers

![Controllers](/assets/tg-ios/part-5-controllers.png "Common Controllers"){: .fit-img :}

[`ViewController`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/ViewController.swift#L76) makes `UIViewController` work as a container of node hierarchies. Unlike the official node controller class [`ASViewController`](https://texturegroup.org/docs/containers-asviewcontroller.html), it doesn’t have features like [visibility depth](https://texturegroup.org/docs/asvisibility.html) and [intelligent preloading](https://texturegroup.org/docs/intelligent-preloading.html).

```swift
@objc open class ViewController: UIViewController, ContainableController {
    // the root content node
    private var _displayNode: ASDisplayNode?
    public final var displayNode: ASDisplayNode {
        get {
            if let value = self._displayNode {
                return value
            }
            else {
                self.loadDisplayNode()
                ...
                return self._displayNode!
            }
        }
        ...
    }
    open func loadDisplayNode()
    open func displayNodeDidLoad()
    
    // shared components
    public let statusBar: StatusBar
    public let navigationBar: NavigationBar?
    private(set) var toolbar: Toolbar?
    private var scrollToTopView: ScrollToTopView?
    // customizations of navigationBar
    public var navigationOffset: CGFloat
    open var navigationHeight: CGFloat
    open var navigationInsetHeight: CGFloat
    open var cleanNavigationHeight: CGFloat
    open var visualNavigationInsetHeight: CGFloat
    public var additionalNavigationBarHeight: CGFloat
}
```

Each ViewController manages the node hierarchy by a root content node, which is stored in the `displayNode` property of the class. There are functions `loadDisplayNode` and `displayNodeDidLoad` to achieve the same lazy view loading behavior as what we are familiar with in `UIViewController`.

As a base class, it prepares several shared node components for subclasses: a status bar, a navigation bar, a toolbar, and a `scrollToTopView`. There are also convenient properties to customize its navigation bar which is still a cumbersome problem for a normal `UIViewController`.

`ViewController` is rarely used in isolation, there are over 100 controller subclasses in the project for different user interfaces. The two most commonly used container controllers in UIKit, `UINavigationController` and `UITabBarController`, are re-implemented as `NavigationController` and `TabBarController`.

```swift
open class NavigationController: UINavigationController, ContainableController, UIGestureRecognizerDelegate {
    private var _viewControllers: [ViewController] = []
    // NavigationControllerNode
    private var _displayNode: ASDisplayNode?
    private var theme: NavigationControllerTheme
    
    // manage layout and transition animation
    private func updateContainers(layout rawLayout: ContainerViewLayout, transition: ContainedViewLayoutTransition)
    
    // push with a completion handler
    public func pushViewController(_ controller: ViewController, animated: Bool = true, completion: @escaping () -> Void)
}

// NavigationLayout.swift
enum RootNavigationLayout {
    case split([ViewController], [ViewController])
    case flat([ViewController])
}

// NavigationContainer.swift
final class NavigationContainer: ASDisplayNode, UIGestureRecognizerDelegate
    override func didLoad() {
        // the interactive pop gesture
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: ...)
    }
}
```

[`NavigationController`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/Navigation/NavigationController.swift#L105) extends `UINavigationController` to borrow its public APIs as it might work with normal view controllers. It rebuilds everything internally including the followings:

- Direct management of sub-controllers. It gives freedom to tweak some edge cases for stack manipulation as it’s just a simple array.
- Transition animation. You can find all the animation details in [`ContainedViewLayoutTransition`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/ContainedViewLayoutTransition.swift#L65).
- Interactive pop gesture. An [`InteractiveTransitionGestureRecognizer`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/InteractiveTransitionGestureRecognizer.swift#L62) is added to enable the pop gesture to all screen area.
- Split master details layout for large screens like iPad. It supports two types of layout: `flat` and `split`. It’s nice to have one container controller to support both iPhone and iPad instead of extract efforts on `UISplitViewController`.
- Themes. It’s easy to customize the look and feel via the property `theme`.

[`TabBarController`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/TabBarController.swift#L75) is only used in the root screen, so it’s a subclass of `ViewController` instead of `UITabBarController` since there is no need to keep the APIs. The same rule applies to [`ActionSheetController`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/ActionSheetController.swift#L4), [`AlertController`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/AlertController.swift#L70), and [`ContextMenuController`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/ContextMenuController.swift#L15). The implementation perfectly covers details inside the system view controllers, the user experience is almost identical to users IMO.

[`ItemListController`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/ItemListUI/Sources/ItemListController.swift#L105) is equivalent to `UITableViewController` by managing a `ListView`. It also supports custom overlay nodes, search view, and reordering items.

# 4. Layout

The Flexbox layout system in AsyncDisplayKit is replaced by a mixed layout mechanism:

```swift
// NavigationBar.swift
//   layout in the main thread
open class NavigationBar: ASDisplayNode {
    override open func layout() {
        super.layout()
        
        if let validLayout = self.validLayout, self.requestedLayout {
            self.requestedLayout = false
            self.updateLayout(size: validLayout.0, defaultHeight: validLayout.1, additionalHeight: validLayout.2, leftInset: validLayout.3, rightInset: validLayout.4, appearsHidden: validLayout.5, transition: .immediate)
        }
    }
    func updateLayout(size: CGSize, defaultHeight: CGFloat, additionalHeight: CGFloat, leftInset: CGFloat, rightInset: CGFloat, appearsHidden: Bool, transition: ContainedViewLayoutTransition)
}

// TabBarController.swift
//   layout in the main thread
open class TabBarController: ViewController {
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.tabBarControllerNode.containerLayoutUpdated(layout, toolbar: self.currentController?.toolbar, transition: transition)
        ...
    }
}


// ListView.swift
//     asynchronously load visible items by the scrolling event
open class ListView: ASDisplayNode, ... {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateScrollViewDidScroll(scrollView, synchronous: false)
    }
    private func updateScrollViewDidScroll(_ scrollView: UIScrollView, synchronous: Bool) {
        ...
        self.enqueueUpdateVisibleItems(synchronous: synchronous)
    }
    private func enqueueUpdateVisibleItems(synchronous: Bool) {
        ...
        strongSelf.updateVisibleItemsTransaction(synchronous: synchronous, completion:...)
    }
    private func updateVisibleItemsTransaction(synchronous: Bool, completion: @escaping () -> Void)
}
```

- All layout is done manually. It’s apparently the engineers don’t like the concept of auto layout.
- Layout computation runs in the main thread for simple UIs. The layout code can be put inside the `layout` method for nodes, or in the `containerLayoutUpdated` method for view controllers.
- `ListView` builds a flexible layout mechanism for its item nodes, which supports both synchronous and asynchronous computation.

# 5. Conclusion

I’m impressed by Telegram’s approach of integrating AsyncDisplayKit. It rebuilds the whole family of UIKit components upon nodes for efficiency and full control. The chat message list feels fluid on old devices although the bubbles UI is complex to render. There are few codes to deal with the system upgrade debt, which always costs some “happy time” from most engineers after WWDC every year. Let’s see what might be broken for other products after the first online WWDC in two weeks.