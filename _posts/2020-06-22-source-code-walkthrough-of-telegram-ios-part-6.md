---
layout: post
title: "Source Code Walkthrough of Telegram-iOS Part 6: Bubbles"
subtitle: ""
cover-img: "/assets/tg-ios/part-6-cover.jpg"
tags: [Telegram, iOS]
comments: true
---

Bubbles is a type of UI that‘s almost an integral part of our daily life. It’s a trivial job if a message is either a piece of plain text or one image file. The problem in Telegram is difficult as there are many message elements, such as texts, styled texts, markdown texts, images, albums, videos, files, web pages, locations, and more. It gets more challenging as one message can have almost multiple elements of arbitrary types. This article shows how Telegram-iOS builds message bubbles upon its asynchronous UI framework.

# 1. Overview of Classes

![Bubble Nodes](/assets/tg-ios/part-6-bubble-nodes.png){: .fit-img :}

[`ChatControllerImpl`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatController.swift#L145) is the core controller that manages the message list UI. Its content [`ChatControllerNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatControllerNode.swift#L59) composes the UI structure with the following major nodes:

```swift
class ChatControllerNode: ASDisplayNode, UIScrollViewDelegate {
    ...
    let backgroundNode: WallpaperBackgroundNode  // background wallpaper
    let historyNode: ChatHistoryListNode // message list
    let loadingNode: ChatLoadingNode  // loading UI
    ...
    private var textInputPanelNode: ChatTextInputPanelNode? // text input
    private var inputMediaNode: ChatMediaInputNode? // media input
    
    let navigateButtons: ChatHistoryNavigationButtons // the navi button at the bottom right
}
```

As a subclass of [`ListView`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/ListView.swift#L134), [`ChatHistoryListNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatHistoryListNode.swift#L397) renders a list of messages and other information nodes. It has two UI modes: [`bubbles`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatHistoryListNode.swift#L76) and [`list`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatHistoryListNode.swift#L77). The mode `bubbles` is used for normal chats and `list` is used in the peer info panel to list chat history per type as Media, Files, Voice, etc. This post only talks about the mode `bubbles`.

Its core data property [`items`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/ListView.swift#L260) can take three types of [`ListViewItem`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Display/Source/ListViewItem.swift#L41). Each item implements `nodeConfiguredForParams` to return the corresponding UI node.

```swift
public protocol ListViewItem {
    ...
    func nodeConfiguredForParams(
        async: @escaping (@escaping () -> Void) -> Void, 
        params: ListViewItemLayoutParams, 
        synchronousLoads: Bool, 
        previousItem: ListViewItem?, 
        nextItem: ListViewItem?, 
        completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void
    )
}
```

[`ChatMessageItem`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatMessageItem.swift#L223) represents a chat message or a group of chat messages that should be rendered as bubbles. Four subclasses of [`ChatMessageItemView`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatMessageItemView.swift#L644) are the container nodes for different types of bubbles.

[`ChatMessageBubbleItemNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatMessageBubbleItemNode.swift#L152) implements a mechanism to render a message bubble having multiple content elements that are subclasses of [`ChatMessageBubbleContentNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatMessageBubbleContentNode.swift#L110).

# 2. List Inversion

A chat message list places the latest message at the bottom and the vertical scroll indicator starts at the bottom too. It’s actually an inversion of the common list UI on iOS. Telegram-iOS uses a similar UI transformation trick that’s present in [`ASTableNode`](https://texturegroup.org/docs/inversion.html) of AsyncDisplayKit. `ChatHistoryListNode` is rotated by 180° using the property `transform` of `ASDisplayNode`, then all content nodes are rotated too.

```swift
// rotate the list node
public final class ChatHistoryListNode: ListView, ChatHistoryNode {
    public init(...) {
        self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
    }
}

// rotate content nodes
public class ChatMessageItemView: ListViewItemNode {
    public init(...) {
        self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
    }
}

final class ChatMessageShadowNode: ASDisplayNode {
    override init() {
        self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
    }
}

final class ChatMessageDateHeaderNode: ListViewItemHeaderNode {
    init() {
        self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
    }
}
...
```

The following screenshot demonstrates what it looks like after applying the transformation step by step:

![Bubble Nodes](/assets/tg-ios/part-6-list-invertion.png)

# 3. ListView Items

- [`ChatBotInfoItem`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatBotInfoItem.swift#L19). The bot information card is inserted at the first position of items if the peer is a Telegram bot.
- [`ChatUnreadItem`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatUnreadItem.swift#L12). It’s an indicator that separates unread and read messages.
- [`ChatMessageItem`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatMessageItem.swift#L268). It models a chat message as following:

```swift
public final class ChatMessageItem: ListViewItem, CustomStringConvertible {
    ...
    let chatLocation: ChatLocation
    let controllerInteraction: ChatControllerInteraction
    let content: ChatMessageItemContent
    ...
}

public enum ChatLocation: Equatable {
    case peer(PeerId)
}

public enum ChatMessageItemContent: Sequence {
    case message(
        message: Message, 
        read: Bool, 
        selection: ChatHistoryMessageSelection, 
        attributes: ChatMessageEntryAttributes)
    case group(
        messages: [(Message, Bool, ChatHistoryMessageSelection, ChatMessageEntryAttributes)])
}
```

[`ChatControllerInteraction`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatControllerInteraction.swift#L52) is a data class that maintains 77 action callbacks for `ChatControllerImpl`. It’s passed through items to enable them trigger callbacks without a reference to the controller.

The structure of [`ChatMessageItemContent`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatMessageItem.swift#L15) is interesting. It’s an enum that can be either one message or a group of messages. IMO, it could be simplified to just `.group` as `.message` can be expressed by a group with one element.

[`Message`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Postbox/Sources/Message.swift#L487) works with two protocols [`MessageAttribute`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Postbox/Sources/Message.swift#L468) and [`Media`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Postbox/Sources/Media.swift#L75) to describe content elements inside a message.

```swift
public final class Message {
    ....
    public let author: Peer?
    public let text: String
    public let attributes: [MessageAttribute]
    public let media: [Media]
    ...
}

public protocol MessageAttribute: class, PostboxCoding { ... }

public protocol Media: class, PostboxCoding {
    var id: MediaId? { get }
    ...
}
```

An instance of `Message` always has one `text` entry and some optional `MessageAttribute`. If `attributes` has an entry of [`TextEntitiesMessageAttribute`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/SyncCore/Sources/TextEntitiesMessageAttribute.swift#L129), an attributed string can be constructed via [`stringWithAppliedEntities`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TextFormat/Sources/StringWithAppliedEntities.swift#L49). Then a rich formatted text can be rendered inside a bubble.

```swift
// For example, this one states the entities inside a text
public class TextEntitiesMessageAttribute: MessageAttribute, Equatable {
    public let entities: [MessageTextEntity]
}

public struct MessageTextEntity: PostboxCoding, Equatable {
    public let range: Range<Int>
    public let type: MessageTextEntityType
}

public enum MessageTextEntityType: Equatable {
    public typealias CustomEntityType = Int32
    
    case Unknown
    case Mention
    case Hashtag
    case Url
    case Email
    case Bold
    case Italic
    case Code
    ...
    case Strikethrough
    case BlockQuote
    case Underline
    case BankCard
    case Custom(type: CustomEntityType)
}
```

The protocol `Media` and its class implementations describe a rich set of media types, such as [`TelegramMediaImage`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/SyncCore/Sources/TelegramMediaImage.swift#L53), [`TelegramMediaFile`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/SyncCore/Sources/TelegramMediaFile.swift#L237), [`TelegramMediaMap`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/SyncCore/Sources/TelegramMediaMap.swift#L133), etc.

To summarize, `Message` is basically an attributed string with several media attachments, while `ChatMessageItem` is a group of `Message` instances. This design is flexible to represent complex message content and keep backward compatibility easily. For example, a [grouped album](https://telegram.org/blog/albums-saved-messages) is expressed as an item that has several messages, while each has a media of [`TelegramMediaImage`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/SyncCore/Sources/TelegramMediaImage.swift#L53).

# 4. Bubble Nodes

`ChatMessageItem` implements [`nodeConfiguredForParams`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatMessageItem.swift#L378) to set up bubble nodes to match the data. If we look into the code, it has some rules on the item structure.

- If the first message has an animated sticker media file that is smaller than 128 KB, [`ChatMessageAnimatedStickerItemNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatMessageAnimatedStickerItemNode.swift#L35) is chose to render a bubble with the sticker. Other messages and media data in the item would be ignored.
- By default, the setting of large emoji support is turned on in the app. If a text message only has one emoji character or all characters are emojis, `ChatMessageAnimatedStickerItemNode` or [`ChatMessageStickerItemNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatMessageStickerItemNode.swift#L20) is used to achieve a large rendering effect instead of plain text.

![Emoji](/assets/tg-ios/part-6-emoji.png){: .fit-img :}

- If the first message of an item has an instant round video file, [`ChatMessageInstantVideoItemNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatMessageInstantVideoItemNode.swift#L22) is selected to display the round video and other content would be ignored.
- Otherwise, [`ChatMessageBubbleItemNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatMessageBubbleItemNode.swift#L152) handles the structured messages.

`ChatMessageBubbleItemNode` checks through an item and builds the sub-nodes by mapping the data to 16 subclasses of [`ChatMessageBubbleContentNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatMessageBubbleContentNode.swift#L110). [`contentNodeMessagesAndClassesForItem`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatMessageBubbleItemNode.swift#L32) is the core function that maintains the mapping logic:

```swift
private func contentNodeMessagesAndClassesForItem(_ item: ChatMessageItem) -> [(Message, AnyClass, ChatMessageEntryAttributes)] {
    var result: [(Message, AnyClass, ChatMessageEntryAttributes)] = []
    ...
    outer: for (message, itemAttributes) in item.content {
        inner: for media in message.media {
            if let _ = media as? TelegramMediaImage {
                result.append((message, ChatMessageMediaBubbleContentNode.self, itemAttributes))
            } else if {...}
        }
        
        var messageText = message.text
        if !messageText.isEmpty ... {
            result.append((message, ChatMessageTextBubbleContentNode.self, itemAttributes))
        }
    }
    ...
}
```

# 5. Layout

![Emoji](/assets/tg-ios/part-6-layout.png)

The layout of bubbles is driven by the asynchronous layout mechanism of `ListView`. The graph above shows the invocation flow of the most important layout methods. During my test on an iPhone 6s with iOS 13.5, the FPS is able to keep above 58 which is better than other apps that have long and complex list UIs. It definitely proves `AsyncDisplayKit` is a good choice for Telegram’s scenario.

One thing to note is that `ListView` doesn’t cache layout results. If your device is really slow, you would see empty cells during scrolling.

# 6. Conclusion

This post briefly explains the data model and UI structures for message bubbles in Telegram-iOS. The data structure is flexible for complex messages, which is a good reference to check if you start to design your own messenger. I encourage you to dive into the code following my introduction as more details are not covered here.