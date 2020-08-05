---
layout: post
title: "Source Code Walkthrough of Telegram-iOS Part-7: Link Preview and Instant View"
subtitle: ""
cover-img: "/assets/tg-ios/part-7-cover.jpg"
tags: [Telegram, iOS]
comments: true
---

Telegram builds a set of features to make users consume content inside the app. This article explains why Telegram needs these features and how they are implemented efficiently.

# Content Platform in Messenger

Before we dive into the technical details, we could think about the role of the content platform from the perspective of a messenger. Why is it important although there is no centralized newsfeed inside Telegram?

If we could only pick one metric for an IM to be successful, it’s definitely the **reachability** of messages. Higher reachability gives users more confidence that messages they send would be viewed by peers reliably, which should be the ultimate cause that keeps them loyal to a messenger. A content platform is proved to be a killer feature to boost reachability as users would use the app more frequently even there are no messages to check, which eventually helps them check new messages faster.

In order to provide a good experience to read content from 3rd party websites, a messenger product needs a mechanism to get structured data. Otherwise, it has to open links within a browser widget, which gives fragmented user experience due to longer page load time and non-native page rendering. The mainstream IM apps employ different ways to improve it. One approach is to ask publishers to provide structured data voluntarily:

- A hosted publishing service. By migrating publishers to use a hosted publishing editor, giant messenger apps like WeChat get structured data from authors directly via its [Official Account Platform](https://mp.weixin.qq.com/?lang=en_US). It’s one of the largest content distribution services in China that generates billions of page views inside the app per day.
- A sharing SDK for other apps to send links into the messenger and fill the required metadata manually like the title, icon, and description. Again it’s a strategy leveraged by WeChat, it saves the engineering effort of building a generic web crawler that can extract structured data from web pages.

Apparently, the approach only works when your product dominates the market as WeChat is acting in China. It’s not practical to do it in the global market. Telegram has applied smart designs to build its current content system:

- [Link Preview](https://telegram.org/blog/link-preview) that was shipped in April 2015 to show rich preview bubbles for most websites. Telegram crawler is built to extract content from links. It’s similar to [Facebook Crawler](https://developers.facebook.com/tools/debug/) that reads [open graph markups](https://developers.facebook.com/docs/sharing/webmasters#markup) inside HTML content. The crawler runs on Telegram data centers and it doesn’t leak any client information to 3rd party web sites.
- [In-App Media Playback](https://telegram.org/blog/search-and-media) was added in the same year to play media from Youtube, Vimeo, and SoundCloud without viewing it in a browser widget. More supported media services have been added later, such as Instagram, Twitch, etc.
- [Instant View](https://telegram.org/blog/instant-view) was introduced in 2016, which is an elegant way to open articles from news services with zero page load time. From the engineering perspective, it’s similar to [Facebook Instant Articles](https://en.wikipedia.org/wiki/Facebook_Instant_Articles) that was debuted in 2015.
- [Telegraph](https://telegra.ph/) was also launched along with Instant View. It is a publishing tool for hosting richly formatted articles on Telegram data centers.
- [Instant View Platform and Contest](https://telegram.org/blog/instant-view-contest-200K#instant-what) were launched in 2017. An online template editor and some generous awards were provided to incentivize users to contribute templates for more websites.
- [Instant View 2.0](https://telegram.org/blog/translations-iv2#instant-view-2-0) was shipped in late 2018 with support for RTL, tables, blocks of relevant articles, etc.

To sum up, Link Preview gives a quick impression of links to users via richly formatted bubbles. In-App Media Playback enables users to enjoy core media content in the links without leaving the chat UI. Instant View renders articles natively with zero page load time. Instant View Platform enables users to contribute templates in a crowdsourcing manner to expand support for more websites.

# Link Preview

As explained in the previous article about [bubbles](/2020-06-22-source-code-walkthrough-of-telegram-ios-part-6/), [`ChatMessageItem`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatMessageItem.swift#L268) can include many types of [`Media`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/Postbox/Sources/Media.swift#L75). One implementation is [`TelegramMediaWebpage`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/SyncCore/Sources/TelegramMediaWebpage.swift#L286), which models data of web links.

```swift
final public class TelegramMediaWebpage : Postbox.Media, Equatable {
    public var id: Postbox.MediaId? { get }
    public let peerIds: [Postbox.PeerId]
    public let webpageId: Postbox.MediaId
    public let content: SyncCore.TelegramMediaWebpageContent
    ...
}

public enum TelegramMediaWebpageContent {
    case Pending(Int32, String?)
    case Loaded(TelegramMediaWebpageLoadedContent)
}

public final class TelegramMediaWebpageLoadedContent: PostboxCoding, Equatable {
    public let url: String
    public let displayUrl: String
    public let hash: Int32
    public let type: String?
    public let websiteName: String?
    public let title: String?
    public let text: String?
    public let embedUrl: String?
    public let embedType: String?
    public let embedSize: PixelDimensions?
    public let duration: Int?
    public let author: String?
    public let image: TelegramMediaImage?
    public let file: TelegramMediaFile?
    public let attributes: [TelegramMediaWebpageAttribute]
    public let instantPage: InstantPage?
}
```

[`ChatMessageWebpageBubbleContentNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/ChatMessageWebpageBubbleContentNode.swift#L95) renders link previews in chat bubbles:

```swift
final class ChatMessageWebpageBubbleContentNode: ChatMessageBubbleContentNode {
    private var webPage: TelegramMediaWebpage?
    private let contentNode: ChatMessageAttachedContentNode
}

final class ChatMessageAttachedContentNode: ASDisplayNode {
    private let lineNode: ASImageNode
    private let textNode: TextNode
    private let inlineImageNode: TransformImageNode
    private var contentImageNode: ChatMessageInteractiveMediaNode?
    private var contentInstantVideoNode: ChatMessageInteractiveInstantVideoNode?
    private var contentFileNode: ChatMessageInteractiveFileNode?
    private var buttonNode: ChatMessageAttachedContentButtonNode?
    
    private let statusNode: ChatMessageDateAndStatusNode
    private var additionalImageBadgeNode: ChatMessageInteractiveMediaBadge?
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private var message: Message?
    private var media: Media?
}
```

Let’s use a [YouTube link](https://www.youtube.com/watch?v=GEZhD3J89ZE) to illustrate what would happen to send it and render its preview bubble.

![Youtube](/assets/tg-ios/part-7-youtube.png){: .fit-img :}

While composing the message, the client detects there is a link inside the input text, it starts an RPC of [`messages.getWebPagePreview`](https://core.telegram.org/method/messages.getWebPagePreview) for preview data. The backend responds with [`MessageMedia.messageMediaWebPage`](https://core.telegram.org/constructor/messageMediaWebPage), which has the link preview data:

```swift
public enum MessageMedia: TypeConstructorDescription {
    case messageMediaWebPage(webpage: Api.WebPage)
}

public enum WebPage: TypeConstructorDescription {
    case webPage(
      flags: Int32,          // 127
      id: Int64,             // 1503448449063263326
      url: String,           // https://www.youtube.com/watch?v=GEZhD3J89ZE
      displayUrl: String,    // youtube.com/watch?v=GEZhD3J89ZE
      hash: Int32,           // 0
      type: String?,         // video
      siteName: String?,     // YouTube
      title: String?,        // WWDC 2020 Special Event Keynote —  Apple
      description: String?,  // Apple WWDC 2020 kicked off with big announcement...
      photo: Api.Photo?,     // TelegramApi.Api.Photo.photo(flags: 0, id: 6020589086160562979, ...
      embedUrl: String?,     // https://www.youtube.com/embed/GEZhD3J89ZE
      embedType: String?,    // iframe
      embedWidth: Int32?,    // 1280
      embedHeight: Int32?,   // 720
      duration: Int32?,      // nil
      author: String?,       // nil
      document: Api.Document?,  // nil
      cachedPage: Api.Page?,    // nil
      attributes: [Api.WebPageAttribute]? // nil
    )
}
```

After tapping the send button, an RPC [`messages.sendMessage`](https://core.telegram.org/method/messages.sendMessage) is fired and the client is waiting for a reply from the backend. While waiting, a sent message bubble is added to the chat bubble list. If the client already gets the response of [`messages.getWebPagePreview`](https://core.telegram.org/method/messages.getWebPagePreview), the bubble is rendered in a beautiful preview bubble. Otherwise, it simply displays a plain text message first and waits for the preview data from the send result in [`Updates.updates`](https://core.telegram.org/constructor/updates).

Then after tapping the play button, the function [`openChatMessageImpl`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/OpenChatMessage.swift#L245) starts and eventually creates an instance of [`WebEmbedPlayerNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUniversalVideoContent/Sources/WebEmbedPlayerNode.swift#L63) to play the YouTube video.

# In-App Media Playback

[`WebEmbedPlayerNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUniversalVideoContent/Sources/WebEmbedPlayerNode.swift#L63) leverages [YouTube IFrame Player API](https://developers.google.com/youtube/iframe_api_reference) to play videos inside `WKWebView`.

- Function [`webEmbedType`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUniversalVideoContent/Sources/WebEmbedPlayerNode.swift#L38) detects the type of embedded content by trying [`extractYoutubeVideoIdAndTimestamp`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUniversalVideoContent/Sources/YoutubeEmbedImplementation.swift#L7) to extract the YouTube video ID from the URL string.
- `WebEmbedPlayerNode` is initialized with [`YoutubeEmbedImplementation`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUniversalVideoContent/Sources/YoutubeEmbedImplementation.swift#L86).
- `YoutubeEmbedImplementation` loads the HTML template [`Youtube.html`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Resources/WebEmbed/Youtube.html) from bundled resources, generates the page content with the video ID, and then loads it by `WKWebView` using `https://youtube.com/` as the base URL.
- A bundled JavaScript file [`YoutubeUserScrip.js`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Resources/WebEmbed/YoutubeUserScript.js) is also injected to hide the [watermark](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Resources/WebEmbed/YoutubeUserScript.js#L19) and [controls](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Resources/WebEmbed/YoutubeUserScript.js#L22) from the embedded YouTube player.
- `YoutubeEmbedImplementation` implements protocol methods to play, pause, and seek the embedded player via JavaScript calls.

Similar approaches are applied to other media services that provide content of long videos or live streamings, such as [`Vimeo`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUniversalVideoContent/Sources/VimeoEmbedImplementation.swift), [`Twitch`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUniversalVideoContent/Sources/TwitchEmbedImplementation.swift), and [`generic`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUniversalVideoContent/Sources/GenericEmbedImplementation.swift) sites that can be embedded as an iframe.

For services like Instagram and TikTok that mostly hosts short videos and photos, Telegram Crawler aggressively caches media content on Telegram data centers and they are served as native videos via [`SystemVideoContentNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUniversalVideoContent/Sources/SystemVideoContent.swift#L35) or [`NativeVideoContentNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUniversalVideoContent/Sources/NativeVideoContent.swift#L85).

It seems Telegram already maintains a large volume of user interaction data and media content on its own backend, it has the potential to build a competitive content aggregation service IMO if their product team wants to.

# Instant View

![Youtube](/assets/tg-ios/part-7-instant-view.png){: .fit-img :}

Let’s use the [official Telegram blog on Covid-19](https://telegram.org/blog/coronavirus) to explain the internals of Instant View. The same RPC [`messages.getWebPagePreview`](https://core.telegram.org/method/messages.getWebPagePreview) is requested while composing the link and this time the response has its value set for the field `cachedPage`:

```swift
public enum WebPage: TypeConstructorDescription {
    case webPage(
      flags: Int32,          // 1311
      id: Int64,             // 4108701751117811561
      url: String,           // https://telegram.org/blog/coronavirus
      displayUrl: String,    // telegram.org/blog/coronavirus
      hash: Int32,           // 702078769
      type: String?,         // photo
      siteName: String?,     // Telegram
      title: String?,        // Coronavirus News and Verified Channels
      description: String?,  // Channels are a tool for broadcasting your public messages...
      photo: Api.Photo?,     // TelegramApi.Api.Photo.photo(flags: 0, id: 5777291004297194213, ...
      embedUrl: String?,     // nil
      embedType: String?,    // nil
      embedWidth: Int32?,    // nil
      embedHeight: Int32?,   // nil
      duration: Int32?,      // nil
      author: String?,       // Telegram
      document: Api.Document?,  // nil
      cachedPage: Api.Page?,    // TelegramApi.Api.Page.page(...)
      attributes: [Api.WebPageAttribute]? // nil
    )
}

public enum Page: TypeConstructorDescription {
    case page(
      flags: Int32,             // 0
      url: String,              // https://telegram.org/blog/coronavirus
      blocks: [Api.PageBlock],  // [TelegramApi.Api.PageBlock] 37 values
      photos: [Api.Photo],      // [TelegramApi.Api.Photo] 5 values
      documents: [Api.Document],// [TelegramApi.Api.Document] 2 values
      views: Int32?             // nil
    )
}

// inside blocks
[
  PageBlock.pageBlockCover,
  PageBlock.pageBlockChannel,
  PageBlock.pageBlockTitle,
  PageBlock.pageBlockAuthorDate,
  PageBlock.pageBlockParagraph,
  ...
  PageBlock.pageBlockRelateArticles
]
```

[`Api.Page`](https://core.telegram.org/constructor/page) models the structured data of a link as a list of [`PageBlock`](https://core.telegram.org/type/PageBlock). `PageBlock` defines 28 types of blocks that are either a display unit or a container of blocks. Having container types gives the power to render complex pages with nested structure.

```swift
indirect public enum PageBlock: TypeConstructorDescription {
    case pageBlockUnsupported
    case pageBlockTitle(text: Api.RichText)
    case pageBlockSubtitle(text: Api.RichText)
    case pageBlockAuthorDate(author: Api.RichText, publishedDate: Int32)
    case pageBlockHeader(text: Api.RichText)
    case pageBlockSubheader(text: Api.RichText)
    case pageBlockParagraph(text: Api.RichText)
    case pageBlockPreformatted(text: Api.RichText, language: String)
    case pageBlockFooter(text: Api.RichText)
    case pageBlockDivider
    case pageBlockAnchor(name: String)
    case pageBlockBlockquote(text: Api.RichText, caption: Api.RichText)
    case pageBlockPullquote(text: Api.RichText, caption: Api.RichText)
    case pageBlockCover(cover: Api.PageBlock) // container
    case pageBlockChannel(channel: Api.Chat)
    case pageBlockKicker(text: Api.RichText)
    case pageBlockTable(flags: Int32, title: Api.RichText, rows: [Api.PageTableRow])
    case pageBlockPhoto(flags: Int32, photoId: Int64, caption: Api.PageCaption, url: String?, webpageId: Int64?)
    case pageBlockVideo(flags: Int32, videoId: Int64, caption: Api.PageCaption)
    case pageBlockAudio(audioId: Int64, caption: Api.PageCaption)
    case pageBlockEmbed(flags: Int32, url: String?, html: String?, posterPhotoId: Int64?, w: Int32?, h: Int32?, caption: Api.PageCaption) // container to embed a web view
    case pageBlockEmbedPost(url: String, webpageId: Int64, authorPhotoId: Int64, author: String, date: Int32, blocks: [Api.PageBlock], caption: Api.PageCaption) // container
    case pageBlockCollage(items: [Api.PageBlock], caption: Api.PageCaption) // container
    case pageBlockSlideshow(items: [Api.PageBlock], caption: Api.PageCaption) // container
    case pageBlockList(items: [Api.PageListItem]) // container
    case pageBlockOrderedList(items: [Api.PageListOrderedItem]) // container
    case pageBlockDetails(flags: Int32, blocks: [Api.PageBlock], title: Api.RichText) // container
    case pageBlockRelatedArticles(title: Api.RichText, articles: [Api.PageRelatedArticle])
    case pageBlockMap(geo: Api.GeoPoint, zoom: Int32, w: Int32, h: Int32, caption: Api.PageCaption)
}
```

The module [`InstantPageUI`](https://github.com/TelegramMessenger/Telegram-iOS/tree/release-6.1.2/submodules/InstantPageUI) holds all UI code files of Instant View. [`InstantPageController`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/InstantPageUI/Sources/InstantPageController.swift#L12) is the core controller and its content node [`InstantPageControllerNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/InstantPageUI/Sources/InstantPageControllerNode.swift#L19) manages subnodes and layouts via the function [`updateLayout`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/InstantPageUI/Sources/InstantPageControllerNode.swift#L391). It enumerates page blocks and creates corresponding types of [`InstantPageItem`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/InstantPageUI/Sources/InstantPageItem.swift#L11) for each block.

```swift
private func updateLayout() {
    ...
    let currentLayout = instantPageLayoutForWebPage(webPage, ...)
}

func instantPageLayoutForWebPage(_ webPage: TelegramMediaWebpage, ...) -> InstantPageLayout {
    var items: [InstantPageItem] = []
    ...
    for block in pageBlocks {
        let blockLayout = layoutInstantPageBlock(webpage: webPage, rtl: rtl, block: block, ...)
        let blockItems = blockLayout.flattenedItemsWithOrigin(CGPoint(x: 0.0, y: contentSize.height + spacing))
        items.append(contentsOf: blockItems)
    }
    ...
}

func layoutInstantPageBlock(webpage: TelegramMediaWebpage, rtl: Bool, block: InstantPageBlock, ...) {
    ...
    switch block {
        case let .title(text):
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .authorDate(author: author, date: date):
            ...
    ...
}

final class InstantPageLayout {
    let origin: CGPoint
    let contentSize: CGSize
    let items: [InstantPageItem]
}
```

`InstantPageController` uses the cached page data to show rendered results instantly. Meanwhile, it also sends an RPC [`messages.getWebPage`](https://core.telegram.org/method/messages.getWebPage) to fetch the latest version via function [`actualizedWebpage`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramCore/Sources/WebpagePreview.swift#L78). So the layout function `updateLayout` is usually invoked at least two or more times.

Considering the layout function always runs inside the main thread, it might block the UI if the instant page has huge content blocks. For example, a paragraph with 1MB text that’s extracted from an ebook site would significantly slow down the whole app, while the same amount of text can be easily handled by `WKWebView`. Apparently, the current version of Instant View assumes the page is normally short.

{: .box-note}
Off-topic, WeChat used to distribute articles from official accounts in the form of mobile web sites. In 2018, the client starts to fetch structured data and build HTML content locally, which also caches CSS and JavaScript files in advance. It somehow presents a similar experience of Instant View.

# Instant View Platform

Transforming a link from raw HTML to clean and structured blocks is a difficult industrial problem in the field of search engineers and mobile browsers. Telegram invents its own [rules language](https://instantview.telegram.org/docs#types-of-rules) to model the content extraction process. The language is sophisticated and supports variables, functions, extended XPath, etc. You can check out [sample templates](https://instantview.telegram.org/#sample-templates) built for Medium, Telegraph, and Telegram Blog to understand it quickly.

In order to encourage users to contribute and define rules for more web sites, Telegram builds an [online IDE](https://instantview.telegram.org/#instant-view-editor) and has held two contests with $500k prizes in total. It also gives you the freedom to either make a template publicly to all users or keep it privately on your own website.

# Conclusion

Telegram shares how to build a full-featured content service that supports many external publishers and provides a silky smooth reading experience inside a messenger. It has involved sophisticated product thinking and meticulous engineering work, which sets a high standard for its competitors.