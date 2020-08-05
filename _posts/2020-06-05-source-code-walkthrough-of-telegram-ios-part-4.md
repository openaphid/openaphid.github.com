---
layout: post
title: "Source Code Walkthrough of Telegram-iOS Part 4: MTProto Connections"
subtitle: ""
cover-img: "https://miro.medium.com/max/700/0*fp7iCV6Isw5jhiEz"
tags: [Telegram, iOS]
comments: true
---

TCP is the only active MTProto transport on Telegram-iOS as I explained in the previous post. Let’s continue with the implementation details of connection management for MTProto.

The major parts of network code reside in modules [`TelegramCore`](https://github.com/TelegramMessenger/Telegram-iOS/tree/release-6.1.2/submodules/TelegramCore) and [`MTProtoKit`](https://github.com/TelegramMessenger/Telegram-iOS/tree/release-6.1.2/submodules/MtProtoKit). I started my reading to answer a simple question:

{: .box-note}
How many connections are used by MTProtoKit during the first login process?

The result surprised me: `20` TCP connections to Telegram data centers and `8` HTTPS requests to external services. The common best practice should be using as few connections as possible.

Before diving into the code to reveal the reason, please let me introduce some important concepts.

# 1. Basic Concepts of Connections

## Data Center

Telegram divides its backend servers into 5 data centers. Each has an id and an alias. Alias is useful to compose [URIs for HTTP transport](https://core.telegram.org/mtproto/transports#uri-format), which is not used in the iOS app. Telegram backend associates a registered account to a master DC id. It requires the client to use the correct master data center to access the user data and might use other DC ids to download images, files, etc.

```
DC 1, pluto
DC 2, venus
DC 3, aurora
DC 4, vesta
DC 5, flora
```

Each data center can be connected via multiple IP addresses. It’s common to `NOT` use domain names directly due to several reasons:

- The system DNS service might be unstable, or even [untrustful](https://en.wikipedia.org/wiki/DNS_spoofing).
- IP addresses and ports need to change frequently to react to network issues. Static IPs could be inaccessible in some regions. Then elastic IPs could be deployed to proxy traffic to data centers. The app should be able to update its endpoint configuration in time.
- Solutions like Geo DNS is good for very coarse-grained IP selection. It’s better for the backend to control it directly.

Telegram-iOS includes several seed addresses for a cold start:

```swift
let seedAddressList: [Int: [String]]
            
seedAddressList = [
    1: ["149.154.175.50", "2001:b28:f23d:f001::a"],   //AS59930
    2: ["149.154.167.50", "2001:67c:4e8:f002::a"],    //AS62041
    3: ["149.154.175.100", "2001:b28:f23d:f003::a"],  //AS59930
    4: ["149.154.167.91", "2001:67c:4e8:f004::a"],    //AS62041
    5: ["149.154.171.5", "2001:b28:f23f:f005::a"]     //AS62014
]
```

Telegram owns four AS numbers to announce the IPs: [AS62014](https://bgp.he.net/AS62014), [AS62041](https://bgp.he.net/AS62041), [AS59930](https://bgp.he.net/AS59930), and [AS44907](https://bgp.he.net/AS44907). More static IPs can be found by searching with the AS numbers if you’re interested in it.

## Endpoint Discovery

Telegram-iOS can update endpoints from internal and external services. The approaches work as complementary to others to maximize the success rate of updating. The result is persisted in Keychain with key [`datacenterAddressSetById`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTContext.m#L340).

- [DNS-over-HTTPS](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTBackupAddressSignals.m#L42) via the JSON API from [Google Public DNS](https://developers.google.com/speed/public-dns/docs/doh). `tapv3.stel.com` is the hostname to resolve, and the parameter `random_padding` is set to prevent possible side-channel attacks. An example of request and response is below:

```swift
// https://dns.google.com/resolve?name=apv3.stel.com&type=16&random_padding=Fw8ZQonqP0qOqoa
{
  "Status": 0,
  "Question": [
    {
      "name": "apv3.stel.com.",
      "type": 16
    }
  ],
  "Answer": [
    {
      "name": "apv3.stel.com.",
      "type": 16,
      "data": "\"vEB1g6iW/a5RtZI/Rx33SEzLmRhz+vNenoY7iqAHW35plgToLfkNRVfvlaBsztOTeYSRqFko73rr2lumKmGax2biMcSQ==\""
    },
    {
      "name": "apv3.stel.com.",
      "type": 16,
      "data": "\"pEI+NHncHJCj9S0XzxhhTd3bkPteVxE5UQ8T06KCz0nP591un4Un82id0FyCEDF0BVmxMp+t673l3HAGD+fzR/qaJ1XpQ6KWxNpRLqA74m2UFTI1REP7ZczU2hmbURzSQvWQTxfp9tnGc1EnyqpUYphFb/Vi+sV83iaw6dTGOcKW1Kp/PW2xV99mmSFLBsspQRdUbKWvbrSpmXHbPbkSRZV61NvtaEiODG1We29nG58DUBqdW7m68ae11w\""
    }
  ]
}
```

Google service responds with several DNS TXT records, that can be merged and transformed into a [valid base64 string](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTBackupAddressSignals.m#L104). The client has the RSA public key to decode the data and [deserialize](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTEncryption.m#L848) it into a list of [`MTBackupDatacenterAddress`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTEncryption.m#L834).

There is a trick inside the [code](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTBackupAddressSignals.m#L45). Besides a normal request to `"dns.google.com"`, another request is sent to `"https://www.google.com/resolve"` with the `Host` header being set to `"dns.google.com"`. It looks like it’s doing [domain fronting](https://en.wikipedia.org/wiki/Domain_fronting) to a subdomain of Google, which makes the DNS request pretend to be visiting Google Search. If you check the commit history, domain fronting was used on other self-owned domains: `dns-telegram.appspot.com` and `tcdnb.azureedge.net`. It became obsolete as the technique is [not supported](https://www.theregister.co.uk/2018/04/19/google_domain_fronting/) anymore.

- [DNS-over-HTTPS](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTBackupAddressSignals.m#L143) via [Cloudflare](https://developers.cloudflare.com/1.1.1.1/dns-over-https/). The implementation is similar to the Google solution.

- [CloudKit](https://developer.apple.com/documentation/cloudkit) data. For logged-in users, the same encrypted data can be fetched from CloudKit according to phone numbers.

- [help.getConfig](https://core.telegram.org/method/help.getConfig) method in MTProto. If the client is able to connect to any data center, this RPC can fetch a configuration that includes a list of [`DcOption`](https://core.telegram.org/type/DcOption).

- iOS [PushKit](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramCore/Sources/Network.swift#L491) and [UserNotifications](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/SharedNotificationManager.swift#L273). The payload inside a remote notification can include [one endpoint data](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/SharedNotificationManager.swift#L409) of a data center.

## MTProto Proxy

Besides the normal endpoints that are operated by Telegram’s engineering team, Telegram builds a [crowdsourced proxy system](https://telegram.org/blog/admin-revolution#free-speech), which allows 3rd-party servers to proxy its traffic. Proxy providers are able to show promoted channels to users in exchange. The official proxy code is [open-sourced](https://github.com/TelegramMessenger/MTProxy).

As a reverse proxy that doesn’t introduce additional protocol changes, it’s basically the same as the official endpoints from the client’s perspective.

## Connection Secret

Along with IP and port for a datacenter address, an optional parameter [`secret`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/PublicHeaders/MtProtoKit/MTDatacenterAddress.h#L14) is present to indicate how the client encrypts TCP connections. Please note that it’s a different concept from the [message encryption of MTProto](https://core.telegram.org/mtproto/description#protocol-description). It’s designed to obfuscate the network traffic, which helps counter [DPI (Deep Packet Inspection)](https://en.wikipedia.org/wiki/Deep_packet_inspection).

There are four possible types of the secret:

- `nil`. No special obfuscation is applied.
- [`MTProxySecretType0`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/PublicHeaders/MtProtoKit/MTApiEnvironment.h#L14). It’s a16 bytes secret to transmission the packets like random data. Although the packet structure is hidden, there are still statistical patterns that could be detected by DPI.
- [`MTProxySecretType1`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/PublicHeaders/MtProtoKit/MTApiEnvironment.h#L20). It’s decoded from a 17 bytes data. The first byte is always 0xdd, and the other 16 bytes are the secret. A [padded intermediate format](https://core.telegram.org/mtproto/mtproto-transports#padded-intermediate) is applied to hide the packet pattern.
- [`MTProxySecretType2`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/PublicHeaders/MtProtoKit/MTApiEnvironment.h#L26). It enables fake-TLS that turns a Telegram connection look like a TLS v1.2 connection. The data starts with a byte `0xee`. The following 16 bytes are the secret data. The rest bytes is a UTF-8 encoded string, which is the [SNI](https://en.wikipedia.org/wiki/Server_Name_Indication) domain to use during a TLS handshake.

Let’s take a shared URL of an MTProto proxy as an example. It declares its secret is `MTProxySecretType2` as the string starts with `ee`. The secret data is filled with zeros and the faked domain is `itunes.apple.com`.

```bash
https://t.me/proxy?server=0.0.0.0
    &port=8080
    &secret=ee000000000000000000000000000000006974756e65732e6170706c652e636f6d
# 6974...6f6d can be decoded to "itunes.apple.com"
```

## Connection Selection

As one data center can have a set of addresses, `MTContext` implements a [selection policy](https://github.com/TelegramMessenger/Telegram-iOS/blob/176e4eaad7505b12c86a400b9da6903695b3bc35/submodules/MtProtoKit/Sources/MTContext.m#L795) to pick the one with the earliest failure timestamp.

## Data Center Authorization

Prior to sending MTProto messages to a data center, it’s required to finish [(p, q) authorization](https://core.telegram.org/mtproto/auth_key) with the target DC. It’s referred to as [data center auth info](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTDatacenterAuthInfo.m#L28) inside the code.

## User Authorization

After successful verification by [SMS code or other methods](https://core.telegram.org/api/auth), the master datacenter associates a user account with the client’s [`auth_key_id`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTDatacenterAuthInfo.m#L36), which grants authorization to access the datacenter as the user. If the client wants to access other data centers with the same user account, it needs to [transfer the authorization](https://core.telegram.org/api/datacenter#authorization-transfer) in advance.

## Recap

According to the concepts, here are the requirements for the client to talk to the backend:

- The client needs to know the data center id and its addresses.
- The addresses might be updated by endpoint discovery.
- Telegram supports a special reverse proxy for MTProto.
- If an address is accessible, the client needs to finish data center authorization prior to other data transmission.
- The client should finish the user authorization with its master data center.
- Authorization transfer is required if the client needs to access other data centers with the user account.

# 2. Code Structure

Let’s check how Telegram-iOS organizes the code. It’s illustrated by the diagram below:

![network-module](/assets/tg-ios/part-4-network_modules.svg)

- There is a dependency chain that gives a UI controller access to the network modules. Most controllers depend on a data model of an account, it’s either an instance of [`Account`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramCore/Sources/Account.swift#L818) or [`UnauthorizedAccount`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramCore/Sources/Account.swift#L56).
- The account classes expose their [`Network`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramCore/Sources/Network.swift#L672) instance fields publicly for controllers to send requests.

```swift
public class UnauthorizedAccount {
    ...
    public let network: Network
    ...
}

public class Account {
    ...
    public let network: Network
    ...
}
```

- `Network` encapsulates all interactions with module MTProtoKit and models RPC request-response pairs as Signals.

```swift
/* Code snippets from Network.swift */
public final class Network: NSObject, MTRequestMessageServiceDelegate {
    ...
    func background() -> Signal<Download, NoError>
    
    public func request<T>(
        _ data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>), 
        tag: NetworkRequestDependencyTag? = nil, 
        automaticFloodWait: Bool = true
        ) -> Signal<T, MTRpcError>
    ...
}

// a Signal operator to retry a RPC
public func retryRequest<T>(signal: Signal<T, MTRpcError>) -> Signal<T, NoError>

/* A code snippet to request login code from `Authorization.swift` */
// construct an MTProto API object
let sendCode = 
    Api.functions.auth.sendCode(
        flags: 0, 
        phoneNumber: phoneNumber, 
        currentNumber: nil, 
        apiId: apiId, 
        apiHash: apiHash)
// send the API via `network`
account.network.request(sendCode, automaticFloodWait: false)
```

- Module MTProtoKit implements all the complex logics of endpoint information, authorization data, connection lifetime, encryption of connection and proto, etc.

## Core MTProtoKit Classes

- [`MTContext`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTContext.m). It’s the context for most MTProtoKit classes by sharing and maintaining the important data of all data centers, such as addresses, auth info, etc. It’s not a singleton from the current design and it’s possible to have multiple instances.
- [`MTProto`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTProto.m). It’s the core manager of messages to a specific data center.
- [`MTTcpTransport`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTTcpTransport.m). It manages a TCP connection. One MTProto instance can have up to one transport alive.
- [`MTMessageService`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/PublicHeaders/MtProtoKit/MTMessageService.h). It’s an Objective-C protocol that defines methods to handle RPCs. An MTProto instance can have multiple MTMessageService instances.

# 3. Inside the First Login Process

The typical first login process has four stages: [onboarding screen](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/AuthorizationSequenceSplashController.swift), [phone number screen](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/AuthorizationSequencePhoneEntryController.swift), [verification code screen](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/AuthorizationSequenceCodeEntryController.swift), and [home screen](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/TelegramRootController.swift). Let’s check the number of connections triggered per stage.

![login-flow](/assets/tg-ios/part-4-login-flow.png){: .fit-img :}

Several diagrams are present to illustrate the simplified workflow per stage. Please open the SVG version for the full resolution file as image compression on Medium blurs the charts. Some notes about the diagrams:

- It’s simplified as many intermediate Signals and classes are omitted.
- Orange nodes are code in Swift.
- Green nodes are code in Objective-C.
- Edges in blue represent connections created during the stage, while dotted one means a connection to request data center auth info and bold one means a connection for RPCs.
- Edges in red represent HTTP requests.
- Datacenter nodes in magenta are new IP addresses updated by endpoint discovery, and the black ones are seed addresses.

## Onboarding

![onboarding](/assets/tg-ios/part-4-onboarding.svg)

When the app is launched for the first time, there is no account data and no auth info for each data center. A new instance of `UnAuthorizedAccount` asks `MTContext` to get auth info from DC 1, 2, and 4, which creates TCP connection ① ② ③. The connections are closed once the auth action finishes.

```swift
// UnauthorizedAccount.swift
public class UnauthorizedAccount {
    ...
    init(networkArguments: NetworkInitializationArguments, id: AccountRecordId, rootPath: String, basePath: String, testingEnvironment: Bool, postbox: Postbox, network: Network, shouldKeepAutoConnection: Bool = true) {
        ...
        network.context.performBatchUpdates({
            var datacenterIds: [Int] = [1, 2]
            if !testingEnvironment {
                datacenterIds.append(contentsOf: [4])
            }
            for id in datacenterIds {
                if network.context.authInfoForDatacenter(withId: id) == nil {
                    network.context.authInfoForDatacenter(withIdRequired: id, isCdn: false)
                }
            }
            network.context.beginExplicitBackupAddressDiscovery()
        })
    }
}

// Network.swift
context.setDiscoverBackupAddressListSignal(
    MTBackupAddressSignals.fetchBackupIps(
        testingEnvironment, 
        currentContext: context, 
        additionalSource: wrappedAdditionalSource, 
        phoneNumber: phoneNumber))
```

It also invokes [`beginExplicitBackupAddressDiscovery`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTContext.m#L1177) and starts the signal that’s set up in [`Network`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramCore/Sources/Network.swift#L516). [`fetchBackupIps`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTBackupAddressSignals.m#L304) combines different discovery signals and only consumes the first response with [`fetchConfigFromAddress`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTBackupAddressSignals.m#L227). As explained in the concepts section, it starts 4 HTTP requests: ① ② to Google, ③ to Cloudflare, and ④ to CloudKit.

```objective_c
+ (MTSignal * _Nonnull)fetchBackupIps:(bool)isTestingEnvironment currentContext:(MTContext * _Nonnull)currentContext additionalSource:(MTSignal * _Nullable)additionalSource phoneNumber:(NSString * _Nullable)phoneNumber {
    ...
    NSMutableArray *signals = [[NSMutableArray alloc] init];
    [signals addObject:[self fetchBackupIpsResolveGoogle:isTestingEnvironment phoneNumber:phoneNumber currentContext:currentContext addressOverride:currentContext.apiEnvironment.accessHostOverride]];
    [signals addObject:[self fetchBackupIpsResolveCloudflare:isTestingEnvironment phoneNumber:phoneNumber currentContext:currentContext addressOverride:currentContext.apiEnvironment.accessHostOverride]];
    [signals addObject:[additionalSource mapToSignal:^MTSignal *(MTBackupDatacenterData *datacenterData) {
            ...
        }]];
    return [[[MTSignal mergeSignals:signals] take:1] mapToSignal:^MTSignal *(MTBackupDatacenterData *data) {
        NSMutableArray *signals = [[NSMutableArray alloc] init];
        NSTimeInterval delay = 0.0;
        for (MTBackupDatacenterAddress *address in data.addressList) {
            MTSignal *signal = [self fetchConfigFromAddress:address currentContext:currentContext];
            if (delay > DBL_EPSILON) {
                signal = [signal delay:delay onQueue:[[MTQueue alloc] init]];
            }
            [signals addObject:signal];
            delay += 5.0;
        }
        return [[MTSignal mergeSignals:signals] take:1];
    };
}
```

Now the auth info of DC 2 is ready with connection ②, a new TCP connection ④ is recreated with the auth info as DC 2 is coded as the default master datacenter id:

```swift
// Account.swift
public func accountWithId(accountManager: AccountManager, networkArguments: NetworkInitializationArguments, id: AccountRecordId, encryptionParameters: ValueBoxEncryptionParameters, supplementary: Bool, rootPath: String, beginWithTestingEnvironment: Bool, backupData: AccountBackupData?, auxiliaryMethods: 
    ...
    return initializedNetwork(
        arguments: networkArguments, 
        supplementary: supplementary, 
        datacenterId: 2,  // use DC 2 for unauthrized account
        keychain: keychain, 
        basePath: path, 
        testingEnvironment: beginWithTestingEnvironment, 
        languageCode: localizationSettings?.primaryComponent.languageCode, 
        proxySettings: proxySettings, 
        networkSettings: networkSettings, phoneNumber: nil)
                        |> map { network -> AccountResult in
                            return .unauthorized(UnauthorizedAccount(networkArguments: networkArguments, id: id, rootPath: rootPath, basePath: path, testingEnvironment: beginWithTestingEnvironment, postbox: postbox, network: network, shouldKeepAutoConnection: shouldKeepAutoConnection))
                        }
}
```

In the meantime, Google DoH returns a new address `196.55.216.85` for DC 4. For any newly discovered endpoint, `fetchConfigFromAddress` invokes [`requestDatacenterAddress`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramCore/Sources/Serialization.swift#L243) to send an RPC [`help.getConfig`](https://core.telegram.org/method/help.getConfig) for new configurations.

As a new `MTContext` is [created without copying the internal data](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTBackupAddressSignals.m#L243), it doesn’t know the original context might have the auth info of DC 4. It has to create TCP connection ⑤ for the auth info of DC 4, disconnect it, and then reconnect to it by another connection ⑥ to send the RPC. Connection ⑤ is redundant IMO.

The datacenter addresses inside the returned config from DC 4 are extracted and decoded to `MTDatacenterAddressListData`. Then connection ⑥ is closed.

```swift
// Addresses in Config.config from DC 4
MTDatacenterAddressListData({
    1 =     (
        "149.154.175.51:443#(media no, cdn no, preferForProxy no, secret )",
        "149.154.175.50:443#(media no, cdn no, preferForProxy yes, secret )",
        "2001:0b28:f23d:f001:0000:0000:0000:000a:443#(media no, cdn no, preferForProxy no, secret )"
    );
    2 =     (
        "149.154.167.50:443#(media no, cdn no, preferForProxy no, secret )",
        "149.154.167.51:443#(media no, cdn no, preferForProxy yes, secret )",
        "149.154.167.151:443#(media yes, cdn no, preferForProxy no, secret )",
        "2001:067c:04e8:f002:0000:0000:0000:000a:443#(media no, cdn no, preferForProxy no, secret )",
        "2001:067c:04e8:f002:0000:0000:0000:000b:443#(media yes, cdn no, preferForProxy no, secret )"
    );
    3 =     (
        "149.154.175.100:443#(media no, cdn no, preferForProxy no, secret )",
        "149.154.175.100:443#(media no, cdn no, preferForProxy yes, secret )",
        "2001:0b28:f23d:f003:0000:0000:0000:000a:443#(media no, cdn no, preferForProxy no, secret )"
    );
    4 =     (
        "149.154.167.92:443#(media no, cdn no, preferForProxy no, secret )",
        "149.154.167.92:443#(media no, cdn no, preferForProxy yes, secret )",
        "149.154.165.96:443#(media yes, cdn no, preferForProxy no, secret )",
        "2001:067c:04e8:f004:0000:0000:0000:000b:443#(media yes, cdn no, preferForProxy no, secret )",
        "2001:067c:04e8:f004:0000:0000:0000:000a:443#(media no, cdn no, preferForProxy no, secret )"
    );
    5 =     (
        "91.108.56.143:443#(media no, cdn no, preferForProxy no, secret )",
        "91.108.56.143:443#(media no, cdn no, preferForProxy yes, secret )",
        "2001:0b28:f23f:f005:0000:0000:0000:000a:443#(media no, cdn no, preferForProxy no, secret )"
    );
})
```

The original context replaces its seed datacenter address set with the new config if the new data are different and saves it into Keychain. The change is also dispatched to all listeners. There is a **bug** inside `fetchConfigFromAddress`, `currentAddressSet` is fetched from a wrong context and it’s always nil.

```swift
// MTBackupAddressSignals.m, fetchConfigFromAddress
__strong MTContext *strongCurrentContext = weakCurrentContext;
[result.addressList enumerateKeysAndObjectsUsingBlock:^(NSNumber *nDatacenterId, NSArray *list, __unused BOOL *stop) {
   MTDatacenterAddressSet *addressSet = [[MTDatacenterAddressSet alloc] initWithAddressList:list];
   // Bug here, should use `strongCurrentContext` instead of `context`
   MTDatacenterAddressSet *currentAddressSet = [context addressSetForDatacenterWithId:[nDatacenterId integerValue]];
   // It's always true as `currentAddressSet` is always nil
   if (currentAddressSet == nil || ![addressSet isEqual:currentAddressSet])
   {
       [strongCurrentContext 
           updateAddressSetForDatacenterWithId:[nDatacenterId integerValue] 
                                    addressSet:addressSet 
                            forceUpdateSchemes:true];
       ...
   }
}];

// MTContext.m
- (void)updateAddressSetForDatacenterWithId:(NSInteger)datacenterId 
    addressSet:(MTDatacenterAddressSet *)addressSet 
    forceUpdateSchemes:(bool)updateSchemes {
    ...
    // replace the address set and save it the Keychain
    _datacenterAddressSetById[@(datacenterId)] = addressSet;
    [_keychain setObject:_datacenterAddressSetById 
                  forKey:@"datacenterAddressSetById" 
                   group:@"persistent"];
    ...
    bool shouldReset = previousAddressSetWasEmpty || updateSchemes;
    ...
    // broadcast the change event. `shouldReset` is True if the callee is fetchConfigFromAddress 
    for (id<MTContextChangeListener> listener in currentListeners) {
        [listener 
            contextDatacenterTransportSchemesUpdated:self 
                                        datacenterId:datacenterId 
                                         shouldReset:shouldReset];
    }
}

// MTProto.m
- (void)contextDatacenterTransportSchemesUpdated:(MTContext *)context 
                                    datacenterId:(NSInteger)datacenterId 
                                     shouldReset:(bool)shouldReset {
    ...        
    if (resolvedShouldReset) {
        // reset the current transport
        [self resetTransport];
        [self requestTransportTransaction];
    }
    ...
}
```

While one of the listeners is the MTProto that’s maintaining the active connection ④ to DC 2. It’s commanded to reset its transport and create connection ⑦ to `149.154.167.51` of DC 2.

There is no user interaction so far, let’s refresh the status:

- 7 TCP connections and 4 HTTP requests are created. Connection ⑦ to DC 2 is active while others are closed.
- The client has collected the auth info of DC 1, 2, 4.
- The datacenter address set is updated.

## Enter Phone Number

![network-module](/assets/tg-ios/part-4-phonenumber.svg)

After entering a phone number and tapping the next button, an RPC [`auth.sendCode`](https://core.telegram.org/method/auth.sendCode) is sent through the active connection ⑦ to DC 2. It responds with [`PHONE_MIGRATE_5`](https://core.telegram.org/api/datacenter#registrationauthorization) as the account belongs to DC 5.

```swift
// Authorization.swift
public func sendAuthorizationCode(accountManager: AccountManager, account: UnauthorizedAccount, phoneNumber: String, apiId: Int32, apiHash: String, syncContacts: Bool) -> Signal<UnauthorizedAccount, AuthorizationCodeRequestError> {
    ...
    switch (error.errorDescription ?? "") {
        case Regex("(PHONE_|USER_|NETWORK_)MIGRATE_(\\d+)"):
            let range = error.errorDescription.range(of: "MIGRATE_")!
            // extract data center id from error description
            let updatedMasterDatacenterId = Int32(error.errorDescription[range.upperBound ..< error.errorDescription.endIndex])!
            let updatedAccount = account.changedMasterDatacenterId(accountManager: accountManager, masterDatacenterId: updatedMasterDatacenterId)
            return updatedAccount
            |> mapToSignalPromotingError { updatedAccount -> Signal<(Api.auth.SentCode, UnauthorizedAccount), MTRpcError> in
                return updatedAccount.network.request(sendCode, automaticFloodWait: false)
                |> map { sentCode in
                    return (sentCode, updatedAccount)
                }
            }
    }
    ...
}

// Account.swift, class Account
public func changedMasterDatacenterId(accountManager: AccountManager, masterDatacenterId: Int32) -> Signal<UnauthorizedAccount, NoError> {
    ...
    return accountManager.transaction { ... }
    |> mapToSignal { localizationSettings, proxySettings -> Signal<(LocalizationSettings?, ProxySettings?, NetworkSettings?), NoError> in
        ...
    }
    |> mapToSignal { (localizationSettings, proxySettings, networkSettings) -> Signal<UnauthorizedAccount, NoError> in
        return initializedNetwork(arguments: self.networkArguments, supplementary: false, datacenterId: Int(masterDatacenterId), keychain: keychain, basePath: self.basePath, testingEnvironment: self.testingEnvironment, languageCode: localizationSettings?.primaryComponent.languageCode, proxySettings: proxySettings, networkSettings: networkSettings, phoneNumber: nil)
        |> map { network in
            let updated = UnauthorizedAccount(networkArguments: self.networkArguments, id: self.id, rootPath: self.rootPath, basePath: self.basePath, testingEnvironment: self.testingEnvironment, postbox: self.postbox, network: network)
            updated.shouldBeServiceTaskMaster.set(self.shouldBeServiceTaskMaster.get())
            return updated
        }
    }
}
```

The client acknowledges that DC 5 is the master instead of DC 2. It invokes `initializedNetwork` and creates an instance of `UnauthorizaedAccount` again to resend `auth.sendAuth` to DC 5. Inside `initializedNetwork`, a new `MTContext` is created to support future operations.

As the client doesn’t have the auth info of DC 5 yet, connection ⑧ is made for it. At the same time, the new instance of `UnauthorizaedAccount` unfortunately initiates the same endpoint discovery logic, which causes more unnecessary actions:

- It creates HTTP requests ④ ⑤ ⑥ ⑦ and gets the same address `196.55.216.85` of DC 4 again.
- As the MTContext inside `fetchConfigFromAddress` is unaware of the auth info of DC 4 due to the same copy issue, it creates connection ⑨ for it and ⑩ to send `help.getConfig` again.
- The same address set is returned inside the config data. The `currentAddressSet` bug causes it to invoke `updateAddressSetForDatacenterWithId`.
- The incorrect change event is propagated to the `MTProto` that has the active connection ⑧ to DC 5. It reset it and creates connection ⑪ to continue with the auth info request to DC 5.

After having the auth info, connection ⑪ is closed and ⑫ is started to send auth.sendAuthto DC 5.

Summary for this stage:

- 5 TCP connections and 4 HTTP requests are created. Connection ⑫ to DC 5 and ⑦ to DC 2 are active while others are closed. The caveats of implementation have caused redundant connections and requests.
- The client has auth info of DC 1, 2, 4, 5.
- The list of address set is unchanged although it’s updated again.

{: .box-note}
BTW, if the seed addresses and the backup addresses from DoH don’t work in your network, Telegram-iOS would [prompt you](https://raw.githubusercontent.com/openaphid/openaphid.github.com/temp/assets/proxy.jpg) to [set up proxies](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramUI/Sources/AuthorizationSequenceController.swift#L243) after a 20s timeout, as there is no other workaorounds at the moment.

## Enter Authorization Code

![network-module](/assets/tg-ios/part-4-code.svg)

After entering the login code received from SMS, it’s sent by RPC [`auth.signIn`](https://core.telegram.org/method/auth.signIn) via the active connection ⑫. DC 5 verifies it’s correct and returns [`auth.Authorization.authorization`](https://core.telegram.org/constructor/auth.authorization). The client finally can replace its unauthorized state with a good account by calling [`switchToAuthorizedAccount`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramCore/Sources/Authorization.swift#L18).

After creating new `Account` and `Network` instances, the alive ones are destroyed and connections ⑫ and ⑦ are closed. Connection ⑬ is made with the user auth data to `91.108.56.143` of DC 5. [`ChatHistoryPreloadManager`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramCore/Sources/ChatHistoryPreloadManager.swift) also creates connection ⑭ to DC 5 to [download chat histories](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramCore/Sources/ChatHistoryPreloadManager.swift#L279).

A bunch of RPCs are sent through ⑬ including another `help.getConfig` call in function [`managedConfigurationUpdates`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramCore/Sources/ManagedConfigurationUpdates.swift#L9). The config from DC 5 has a different list of address sets than the one from DC 4, especially the address of DC 5 is changed to `91.108.56.156`. Connections ⑬ and ⑭ are not affected by the new config as [`forceUpdateSchemes`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramCore/Sources/ManagedConfigurationUpdates.swift#L33) is [false](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramCore/Sources/ManagedConfigurationUpdates.swift#L33) in `managedConfigurationUpdates`.

```swift
// Addresses in Config.config from DC 5
MTDatacenterAddressListData({
    1 =     (
        "149.154.175.57:443#(media no, cdn no, preferForProxy no, secret )",
        "149.154.175.50:443#(media no, cdn no, preferForProxy yes, secret )",
        "2001:0b28:f23d:f001:0000:0000:0000:000a:443#(media no, cdn no, preferForProxy no, secret )"
    );
    2 =     (
        "149.154.167.50:443#(media no, cdn no, preferForProxy no, secret )",
        "149.154.167.51:443#(media no, cdn no, preferForProxy yes, secret )",
        "149.154.167.151:443#(media yes, cdn no, preferForProxy no, secret )",
        "2001:067c:04e8:f002:0000:0000:0000:000a:443#(media no, cdn no, preferForProxy no, secret )",
        "2001:067c:04e8:f002:0000:0000:0000:000b:443#(media yes, cdn no, preferForProxy no, secret )"
    );
    3 =     (
        "149.154.175.100:443#(media no, cdn no, preferForProxy no, secret )",
        "149.154.175.100:443#(media no, cdn no, preferForProxy yes, secret )",
        "2001:0b28:f23d:f003:0000:0000:0000:000a:443#(media no, cdn no, preferForProxy no, secret )"
    );
    4 =     (
        "149.154.167.92:443#(media no, cdn no, preferForProxy no, secret )",
        "149.154.167.92:443#(media no, cdn no, preferForProxy yes, secret )",
        "149.154.166.120:443#(media yes, cdn no, preferForProxy no, secret )",
        "2001:067c:04e8:f004:0000:0000:0000:000b:443#(media yes, cdn no, preferForProxy no, secret )",
        "2001:067c:04e8:f004:0000:0000:0000:000a:443#(media no, cdn no, preferForProxy no, secret )"
    );
    5 =     (
        "91.108.56.156:443#(media no, cdn no, preferForProxy no, secret )",
        "91.108.56.156:443#(media no, cdn no, preferForProxy yes, secret )",
        "2001:0b28:f23f:f005:0000:0000:0000:000a:443#(media no, cdn no, preferForProxy no, secret )"
    );
})
```

The home screen is ready to show with the account. Other modules start to fetch resources for the UI components, like the avatar image, etc. All requests are sent via [`multiplexedRequestManager`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramCore/Sources/Network.swift#L686) owned by `account.network`. During this login session, all resources are located on DC 1.

Before the client could download files from DC 1, it has to [transfer its user authorization](https://core.telegram.org/api/datacenter#authorization-transfer) from DC 5 to DC 1. Connection ⑮ is created to ask DC 5 to [export the auth data](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTDatacenterTransferAuthAction.m#L77), connection ⑯ is made to [import the data](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/MtProtoKit/Sources/MTDatacenterTransferAuthAction.m#L119) to DC 1. Both connections are closed after the job is done.

[`MultiplexedRequestManagerContext`](http://modules/TelegramCore/Sources/MultiplexedRequestManager.swift#L73) limits [max to 4 workers per DC](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramCore/Sources/MultiplexedRequestManager.swift#L148). That’s why there are connections ⑰ ⑱ ⑲ ⑳ for [`Download`](https://github.com/TelegramMessenger/Telegram-iOS/blob/release-6.1.2/submodules/TelegramCore/Sources/Download.swift).

# 4. Conclusion

- During the first login process. It might not be good to have 20 TCP connections and 8 HTTP requests, although there are many tasks to finish.
- It’s possible to optimize the usage of connections and requests.
- It requires lots of effects to make a messenger product reliably connect to its data centers. Multiple backup plans are necessary for unexpected network issues. Besides the methods used in Telegram, there are [many other approaches](https://en.wikipedia.org/wiki/Internet_censorship_circumvention) to explore.
- I have mixed feelings about modeling states of connections and data in a purely reactive way. The good thing is that it actually works. But it results in a complex dependency structure with many Signals. Sorting it out is not intuitive even under the help of Xcode debugger, which provides a great feature of showing [recorded stack frames](https://asciiwwdc.com/2014/sessions/413).
- It would be great to integrate debugging tools to help explore the running states, such as [Flipper](https://fbflipper.com/), [FLEX](https://github.com/Flipboard/FLEX), [Timelane](http://timelane.tools/), etc.
