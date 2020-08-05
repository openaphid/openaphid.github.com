---
layout: post
title: "Source Code Walkthrough of Telegram-iOS Part 2: SSignalKit"
subtitle: ""
cover-img: "/assets/tg-ios/part-2-cover.jpg"
tags: [Telegram, iOS]
comments: true
---

Telegram-iOS uses reactive programming in most modules. There are three frameworks to achieve reactive functions inside the project:

- [`MTSignal`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/MtProtoKit/Sources/MTSignal.m): it might be their first attempt for a reactive paradigm in Objective-C. It’s mainly used in the module [MtProtoKit](https://github.com/TelegramMessenger/Telegram-iOS/tree/master/submodules/MtProtoKit), which implements [MTProto](https://core.telegram.org/mtproto), Telegram’s mobile protocol.
- [`SSignalKit`](https://github.com/TelegramMessenger/Telegram-iOS/tree/master/submodules/SSignalKit/SSignalKit): it’s a descendant of MTSignal for more general scenarios with richer primitives and operations.
- [`SwiftSignalKit`](https://github.com/TelegramMessenger/Telegram-iOS/tree/master/submodules/SSignalKit/SwiftSignalKit): an equivalent port in Swift.

This post focuses on SwiftSignalKit to explain its design with use cases.

# Design

## Signal

[`Signal`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Signal.swift#L41) is a class that captures the concept of “change over time”. Its signature can be viewed as below:

```swift
// pseudocode
public final class Signal<T, E> {
    public init(_ generator: @escaping(Subscriber<T, E>) -> Disposable)
    
    public func start(next: ((T) -> Void)! = nil, 
                      error: ((E) -> Void)! = nil, 
                      completed: (() -> Void)! = nil) -> Disposable
}
```

To set up a signal, it accepts a generator closure which defines the ways to generate data(`<T>`), catch errors(`<E>`), and update completion state. Once it’s set up, the function `start` can register observer closures.

## Subscriber

[`Subscriber`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Subscriber.swift) has the logics to dispatch data to each observer closure with thread safety consideration.

```swift
// pseudocode
public final class Subscriber<T, E> {
    private var next: ((T) -> Void)!
    private var error: ((E) -> Void)!
    private var completed: (() -> Void)!
    
    private var terminated = false
    
    public init(next: ((T) -> Void)! = nil, 
                error: ((E) -> Void)! = nil, 
                completed: (() -> Void)! = nil)
    
    public func putNext(_ next: T)
    
    public func putError(_ error: E)
    
    public func putCompletion()
}
```

A subscriber is terminated when an error occurred or it’s completed. The state can not be reversed.

- `putNext` sends new data to the `next` closure as long as the subscriber is not terminated
- `putError` sends an error to the `error` closure and marks the subscriber terminated
- `putCompletion` invokes the `completed` closure and marks the subscriber terminated.

## Operators

A rich set of operators are defined to provide functional primitives on Signal. These primitives are grouped into several categories according to their functions: [`Catch`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Signal_Catch.swift), [`Combine`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Signal_Combine.swift), [`Dispatch`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Signal_Dispatch.swift), [`Loop`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Signal_Loop.swift), [`Mapping`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Signal_Mapping.swift), [`Meta`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Signal_Meta.swift), [`Reduce`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Signal_Reduce.swift), [`SideEffects`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Signal_SideEffects.swift), [`Single`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Signal_Single.swift), [`Take`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Signal_Take.swift), and [`Timing`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Signal_Timing.swift). Let’s take several mapping operators as an example:

```swift
public func map<T, E, R>(_ f: @escaping(T) -> R) -> (Signal<T, E>) -> Signal<R, E>

public func filter<T, E>(_ f: @escaping(T) -> Bool) -> (Signal<T, E>) -> Signal<T, E>

public func flatMap<T, E, R>(_ f: @escaping (T) -> R) -> (Signal<T?, E>) -> Signal<R?, E>

public func mapError<T, E, R>(_ f: @escaping(E) -> R) -> (Signal<T, E>) -> Signal<T, R>
```

The operator like `map()` takes a transformation closure and returns a function to change the data type of a Signal. There is a handy `|>` operator to help chain these operators as pipes:

```swift
precedencegroup PipeRight {
    associativity: left
    higherThan: DefaultPrecedence
}

infix operator |> : PipeRight

public func |> <T, U>(value: T, function: ((T) -> U)) -> U {
    return function(value)
}
```

The operator `|>` might be inspired by the proposed [pipeline operator](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Pipeline_operator) in the JavaScript world. By the trailing closure support from Swift, all operators can be pipelined with intuitive readability:

```swift
// pseudocode
let anotherSignal = valueSignal
    |> filter { value -> Bool in
      ...
    }
    |> take(1)
    |> map { value -> AnotherValue in
      ...
    }
    |> deliverOnMainQueue
```

## Queue

The class [`Queue`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Queue.swift) is a wrapper over GCD to manage the queue used to dispatch data in a Signal. There are three preset queues for general use cases: `globalMainQueue`, `globalDefaultQueue`, and `globalBackgroundQueue`. There is no mechanism to avoid [`overcommit`](https://forums.developer.apple.com/message/338719#338719) to queues, which I think could be improved.

## Disposable

The protocol [`Disposable`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Disposable.swift) defines something that can be disposed of. It’s usually associated with freeing resources or canceling tasks. Four classes implement this protocol and could cover most use cases: `ActionDisposable`, `MetaDisposable`, `DisposableSet`, and `DisposableDict`.

## Promise

The classes [`Promise`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Promise.swift) and [`ValuePromise`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Promise.swift#L82) are built for the scenario when multiple observers are interested in a data source. `Promise` supports using a Signal to update the data value, while `ValuePromise` is defined to accept the value changes directly.

# Use Cases

Let’s check out some real use cases in the project, which demonstrate the usage pattern of SwiftSignalKit.

## #1 Request Authorization
iOS enforces apps to request authorization from the user before accessing sensitive information on devices, such as [contacts](https://developer.apple.com/documentation/contacts/requesting_authorization_to_access_contacts), [camera](https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture/requesting_authorization_for_media_capture_on_ios), [location](https://developer.apple.com/documentation/corelocation/requesting_authorization_for_location_services), etc. While chatting with a friend, Telegram-iOS has a feature to send your location as a message. Let’s see how it gets the location authorization with Signal.

The workflow is a standard asynchronous task that can be modeled by SwiftSignalKit. The function [`authorizationStatus`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/DeviceAccess/Sources/DeviceAccess.swift#L84) inside [`DeviceAccess.swift`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/DeviceAccess/Sources/DeviceAccess.swift) returns a Signal to check the current authorization status:

```swift
public enum AccessType {
    case notDetermined
    case allowed
    case denied
    case restricted
    case unreachable
}

public static func authorizationStatus(subject: DeviceAccessSubject) -> Signal<AccessType, NoError> {
    switch subject {
        case .location:
            return Signal { subscriber in
                let status = CLLocationManager.authorizationStatus()
                switch status {
                    case .authorizedAlways, .authorizedWhenInUse:
                        subscriber.putNext(.allowed)
                    case .denied, .restricted:
                        subscriber.putNext(.denied)
                    case .notDetermined:
                        subscriber.putNext(.notDetermined)
                    @unknown default:
                        fatalError()
                }
                subscriber.putCompletion()
                return EmptyDisposable
            }
    }
}
```

{: .box-note}
The current implementation is piped with another then operation, which I believe it’s a piece of copy-and-paste code, and it should be removed.

When a [`LocationPickerController`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/LocationUI/Sources/LocationPickerController.swift#L295) is present, it observes on the signal from authorizationStatus and invokes `DeviceAccess.authrizeAccess` if the permission is not determined.

`Signal.start` returns an instance of `Disposable`. The best practice is to hold it in a field variable and dispose of it in `deinit`.

```swift
override public func loadDisplayNode() {
    ...

    self.permissionDisposable = 
            (DeviceAccess.authorizationStatus(subject: .location(.send))
            |> deliverOnMainQueue)
            .start(next: { [weak self] next in
        guard let strongSelf = self else {
            return
        }
        switch next {
        case .notDetermined:
            DeviceAccess.authorizeAccess(
                    to: .location(.send),
                    present: { c, a in
                        // present an alert if user denied it
                        strongSelf.present(c, in: .window(.root), with: a)
                    },
                    openSettings: {
                       // guide user to open system settings
                        strongSelf.context.sharedContext.applicationBindings.openSettings()
                    })
        case .denied:
            strongSelf.controllerNode.updateState { state in
                var state = state
                // change the controller state to ask user to select a location
                state.forceSelection = true 
                return state
            }
        default:
            break
        }
    })
}

deinit {
    self.permissionDisposable?.dispose()
}
```

## #2 Change Username

Let’s check out a more complex example. Telegram allows each user to change the unique username in [`UsernameSetupController`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SettingsUI/Sources/UsernameSetupController.swift). The username is used to generate a public link for others to reach you.

![UsernameSetupController](/assets/tg-ios/part-2-UsernameSetupController.jpg "States of UsernameSetupController")

The implementation should meet the requirements:

- The controller starts with the current username and the current theme. Telegram has a powerful [theme system](https://telegram.org/blog/android-themes), all controllers should be themeable.
- The input string should be validated locally first to check its length and characters.
- A valid string should be sent to the backend for the availability check. The number of requests should be limited in case of fast typing.
- UI Feedback should follow the user’s input. The message on the screen should tell the status of the new username: it’s in checking, invalid, unavailable, or available. The right navigation button should be enabled when the input string is valid and available.
- Once the user wants to update the username, the right navigation button should show an activity indicator during updating.

There are three data sources that could change over time: the theme, the current account, and the editing state. The theme and account are fundamental data components in the project, so there are dedicated Signals: [`SharedAccountContext.presentationData`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/AccountContext/Sources/AccountContext.swift#L428) and [`Account.viewTracker.peerView`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/TelegramCore/Sources/AccountViewTracker.swift#L1153). I’ll try to cover them in other posts. Let’s focus on how the editing state is modeled with Signal step by step.

 #1. The struct [`UsernameSetupControllerState`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SettingsUI/Sources/UsernameSetupController.swift#L130) defines the data with three elements: the editing input text, the validation status, and the updating flag. Several helper functions are provided to update it and get a new instance.

```swift
struct UsernameSetupControllerState: Equatable {
    let editingPublicLinkText: String?
    
    let addressNameValidationStatus: AddressNameValidationStatus?
    
    let updatingAddressName: Bool
    
    ...
    
    func withUpdatedEditingPublicLinkText(_ editingPublicLinkText: String?)
        -> UsernameSetupControllerState {
        return UsernameSetupControllerState(
                   editingPublicLinkText: editingPublicLinkText, 
                   addressNameValidationStatus: self.addressNameValidationStatus, 
                   updatingAddressName: self.updatingAddressName)
    }
    
    func withUpdatedAddressNameValidationStatus(
        _ addressNameValidationStatus: AddressNameValidationStatus?) 
        -> UsernameSetupControllerState {
        return UsernameSetupControllerState(
                   editingPublicLinkText: self.editingPublicLinkText, 
                   addressNameValidationStatus: addressNameValidationStatus, 
                   updatingAddressName: self.updatingAddressName)
    }
}

enum AddressNameValidationStatus : Equatable {
    case checking

    case invalidFormat(TelegramCore.AddressNameFormatError)

    case availability(TelegramCore.AddressNameAvailability)
}
```

#2. The state changes are propagated by [`statePromise`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SettingsUI/Sources/UsernameSetupController.swift#L228) in `ValuePromise`, which also provides a neat feature to omit repeated data updates. There is also a [`stateValue`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SettingsUI/Sources/UsernameSetupController.swift#L229) to hold the latest state because the data in a `ValuePromise` is [`not visible`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SSignalKit/SwiftSignalKit/Source/Promise.swift#L83) outside. It’s a common pattern inside the project for a value promise companied with a state value. Exposing read access to the internal value might be an appropriate improvement to `ValuePromise` IMO.

```swift
let statePromise = ValuePromise(UsernameSetupControllerState(), ignoreRepeated: true)

let stateValue = Atomic(value: UsernameSetupControllerState())
```

#3. The validation process can be implemented in a piped Signal. The operator `delay` holds the request for a 0.3 seconds delay. For fast typing, the previous unsent request would be canceled by the setup in Step 4.

```swift
public enum AddressNameValidationStatus: Equatable {
    case checking
    case invalidFormat(AddressNameFormatError)
    case availability(AddressNameAvailability)
}

public func validateAddressNameInteractive(name: String)
                -> Signal<AddressNameValidationStatus, NoError> {
    if let error = checkAddressNameFormat(name) { // local check
        return .single(.invalidFormat(error))
    } else {
        return .single(.checking) // start to request backend
                |> then(addressNameAvailability(name: name) // the request
                |> delay(0.3, queue: Queue.concurrentDefaultQueue()) // in a delayed manner
                |> map { .availability($0) } // convert the result
        )
    }
}
```

#4. A [`MetaDisposable`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SettingsUI/Sources/UsernameSetupController.swift#L239) holds the Signal, and updates the data in `statePromise` and `stateValue` when `text` is changed in `TextFieldNode`. When invoking `checkAddressNameDisposable.set()`, the previous one is disposed of which triggers the canceling task inside the operator `delay` in the 3rd step.

{: .box-note}
[`TextFieldNode`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/Display/Source/EditableTextNode.swift) is a subclass of `ASDisplayNode` and wraps a UITextField for text input. Telegram-iOS leverages the asynchronous rendering mechanism from [`AsyncDisplayKit`](https://github.com/TelegramMessenger/Telegram-iOS/tree/master/submodules/AsyncDisplayKit) to make its complex message UI smooth and responsive.

```swift
let checkAddressNameDisposable = MetaDisposable()

...

if text.isEmpty {
    checkAddressNameDisposable.set(nil)
    statePromise.set(stateValue.modify {
        $0.withUpdatedEditingPublicLinkText(text)
          .withUpdatedAddressNameValidationStatus(nil)
    })
} else {
    checkAddressNameDisposable.set(
        (validateAddressNameInteractive(name: text) |> deliverOnMainQueue)
                .start(next: { (result: AddressNameValidationStatus) in
            statePromise.set(stateValue.modify {
                $0.withUpdatedAddressNameValidationStatus(result)
            })
        }))
}
```

#5. The operator [`combineLatest`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/SettingsUI/Sources/UsernameSetupController.swift#L288) combines the three Signals to update the controller UI if any of them is changed.

```swift
let signal = combineLatest(
                 presentationData, 
                 statePromise.get() |> deliverOnMainQueue, 
                 peerView) {
  // update navigation button
  // update controller UI
}
```

# Conclusion

`SSignalKit` is Telegram-iOS’s solution to reactive programming. The core components, like `Signal` and `Promise`, are implemented in slightly different approaches from other reactive frameworks. It’s used pervasively across the modules to connect UI with data changes.

The design encourages heavy usage of closures. There are many closures nested with each other, which [`indents some lines`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/TelegramUI/Sources/ChatMediaInputNode.swift#L1125) far away. The project also likes [`exposing many actions as closures`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/TelegramUI/Sources/ChatControllerInteraction.swift#L52) for flexibility. It’s still a myth to me on how Telegram engineers maintain the code quality and debug the Signals easily.