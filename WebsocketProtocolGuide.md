## Implementation requirements

The reference implementation of the local proxy provides features that may require OS facilities not available on all device runtime environments in the industry. The following represents 

**Communications Protocols:**
* Websocket protocol ([RFC6455](https://tools.ietf.org/html/rfc6455)) over TCP
* TLS 1.1+ 

**Data processing**
* ProtocolBuffers library
    * Message size requirements are dependent on tunnel peer message sizes

## Protocol Design

The IoT Secure Tunneling's usage of WebSocket is in part a subprotocol as defined by [RFC6455](https://tools.ietf.org/html/rfc6455), and additionally some of the behaviors and restrictions called out in this document. It leverages [ProtocolBuffers](https://developers.google.com/protocol-buffers/) and 2-byte length prefixed frames to transmit those messages. The messages themselves carry data and communicate basic tunnel connectivity information to enable tunnel clients to leverage full duplex communication with reliability and flexibility. The protocol is designed to adapt TCP socket protocol over a tunnel, but it is not limited to being used only for TCP based client or server applications. It is possible to utilize the protocol directly and provide a library, rather than a stand alone process. This guide is intended to assist in those interested in directly interfacing with the WebSocket layer. This document is not a programming guide so it is expected that you are familiar with the following:

-   AWS IoT Secure Tunneling service and the major concepts. Particularly the local proxy as this guide
-   WebSocket and how to use it in your chosen language and API (connect, send, and receive data)
-   ProtocolBuffers and how to use it in your chosen language (generate code, parse messages, create messages)
-   Conceptual familiarity with TCP sockets, and ideally API familiarity in your language of choice

## Connecting to the proxy server and tunnel: WebSocket handshake

The handshake performed to connect to a AWS IoT Secure Tunneling server is a standard WebSocket protocol handshake with additional requirements on the HTTP request constructed. These requirements ensure proper access to a tunnel given a client access token:

-   The tunneling service only accepts connections secured with TLS 1.1 or higher
-   The HTTP path of the upgrade request must be /tunnel. Requests made to any other path will result in a 400 HTTP response
-   There must be a URL parameter specifying the tunnel connection (local proxy) mode. Is this the 'source' side of the tunnel, or the 'destination side. Any other URL parameters present will cause the handshake to fail
-   There must be an access token specified in the request either via cookie, or an HTTP request header
    -   Setting the token via cookie must use the cookie name 'awsiot-tunnel-token'. This cookie will automatically be set to the source token in the response of the OpenTunnel web API over HTTP.
    -   Setting the token via HTTP request header must use the header name 'access-token'.
    -   Only one token value may be present in the request. Supplying multiple values for either the access-token header or the cookie, or both combined will cause the handshake to fail.
    -   The client mode affinity of the access token (source or destination) value used in the request must match the local-proxy-mode query parameter value or the handshake will fail.
-   The HTTP request size must not exceed 4k bytes in length. Requests larger than this are rejected
-   The 'Sec-WebSocket-Protocol' must contain at least one valid protocol string based on what is supported by the service, but may be further constrained by the parameters which created the tunnel.
    -   Currently valid value: 'aws.iot.securetunneling-1.0'

An example URI of where to connect is as follows:

`wss://data.tunneling.iot.us-east-1.amazonaws.com:443`

The regional endpoint selected must match the region where the OpenTunnel call was made to acquire the client access tokens.

An example WebSocket handshake request coming from a local proxy:

```
GET /tunnel?local-proxy-mode=source HTTP/1.1
Host: data.tunneling.iot.us-east-1.amazonaws.com
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Key: 9/h0zvwMEXrg06G+RjnmcA==
Sec-WebSocket-Version: 13
Sec-WebSocket-Protocol: aws.iot.securetunneling-1.0
access-token: AQGAAXiVzSmRL1VaJ22G7eRb\_CrPABsAAgABQQAMOTAwNTgyMDkxNTM4AAFUAANDQVQAAQAHYXdzLWttcwBLYXJuOmF3czprbXM6dXMtZWFzdC0xOjcwMTU0NTg5ODcwNzprZXkvMmU4ZTAxMDEtYzE3YS00NjU1LTlhYWQtNjA2N2I2NGVhZWQyALgBAgEAeAJ2EsT4f5oCWm65Y8zRx\_nNaCjcG4FIeNV\_zMyhoOslAVAr521wChjzvogy-2-mxyoAAAB-MHwGCSqGSIb3DQEHBqBvMG0CAQAwaAYJKoZIhvcNAQcBMB4GCWCGSAFlAwQBLjARBAwfBUUjMYI9gDEp0xwCARCAO1VX0NAiSjfU-Ar9PWYaNI5j9v77CxLcucht3tWZd57-Zq3aRQZBM4SQiy-D0Cgv31IfZ8pgWu8asm5FAgAAAAAMAAAQAAAAAAAAAAAAAAAAACniTwIAksExcMygMJ2uHs3\_\_\_\_\_AAAAAQAAAAAAAAAAAAAAAQAAAC9e5K3Isg5gHqO9LYX0geH4hrfthPEUhdrl9ZLksPxcVrk6XC4VugzrmUvEUPuR00J3etgVQZH\_RfxWrVt7Jmg=
User-Agent: localproxy Mac OS 64-bit/boost-1.68.0/openssl-3.0.0/protobuf-3.6.1
```

An example of an HTTP WebSocket handshake coming from a browser does not have the ability to create the 'access-token' header so it may specify the following:

```
GET /tunnel?local-proxy-mode=source HTTP/1.1
Host: data.tunneling.iot.us-east-1.amazonaws.com
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Key: 9/h0zvwMEXrg06G+RjnmcA==
Sec-WebSocket-Version: 13
Sec-WebSocket-Protocol: aws.iot.securetunneling-1.0
Cookie: awsiot-tunnel-token=AQGAAXiVzSmRL1VaJ22G7eRb\_CrPABsAAgABQQAMOTAwNTgyMDkxNTM4AAFUAANDQVQAAQAHYXdzLWttcwBLYXJuOmF3czprbXM6dXMtZWFzdC0xOjcwMTU0NTg5ODcwNzprZXkvMmU4ZTAxMDEtYzE3YS00NjU1LTlhYWQtNjA2N2I2NGVhZWQyALgBAgEAeAJ2EsT4f5oCWm65Y8zRx\_nNaCjcG4FIeNV\_zMyhoOslAVAr521wChjzvogy-2-mxyoAAAB-MHwGCSqGSIb3DQEHBqBvMG0CAQAwaAYJKoZIhvcNAQcBMB4GCWCGSAFlAwQBLjARBAwfBUUjMYI9gDEp0xwCARCAO1VX0NAiSjfU-Ar9PWYaNI5j9v77CxLcucht3tWZd57-Zq3aRQZBM4SQiy-D0Cgv31IfZ8pgWu8asm5FAgAAAAAMAAAQAAAAAAAAAAAAAAAAACniTwIAksExcMygMJ2uHs3\_\_\_\_\_AAAAAQAAAAAAAAAAAAAAAQAAAC9e5K3Isg5gHqO9LYX0geH4hrfthPEUhdrl9ZLksPxcVrk6XC4VugzrmUvEUPuR00J3etgVQZH\_RfxWrVt7Jmg=
User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:10.0) Gecko/20100101 Firefox/10.0
```

On success, an example of a successful handshake response is:

```
HTTP/1.1 101 Switching Protocols
Date: Thu, 16 May 2019 20:56:03 GMT
Content-Length: 0
Connection: upgrade
channel-id: 0ea2b3fffe6adc0e-0000125a-00005adb-c2f218c35b921565-17c807e1
upgrade: websocket 
sec-websocket-accept: akN+XFrGEeDLcMVNKV9HkQCOLaE=
sec-websocket-protocol: aws.iot.securetunneling-1.0
```

The aspects of the response to consider above a standard WebSocket successful handshake response are:

-   The channel-id response header is helpful for troubleshooting any suspected issues communicating with the service. If an issues occur while connecting or connected to a tunnel, the current channel-id should be provided to AWS Support for troubleshooting.
-   The 'sec-websocket-protocol' response header will contain one of the values specified in the request. That the proxy  Clients must understand and properly implement the subprotocol returned in this response header to ensure valid communication over the tunnel.

After a successful WebSocket handshake with the tunneling service, full duplex communication is possible over WebSocket. WebSocket is a protocol that runs on top of TCP so messages are reliably delivered and are interpreted in order by the user application. Concerns related to message order, and reliable delivery are not built into the tunneling message framing or the messages themselves.

### Handshake error responses

* If the handshake HTTP response code is within the 500-599 range, the client should retry using an exponential backoff retry strategy.
* If the handshake HTTP response code is within the 400-499 range, the client may be forming a bad request, or access to the tunnel is not possible or denied. Do not retry unless the problem is understood and the request changes (i.e. use another region endpoint or different client access token)
* Many handshake error responses will contain the channel-id header which may be helpful for AWS Support troubleshooting

## WebSocket Subprotocol: aws.iot.securetunneling-1.0

While connected to the service with this protocol selected, the following restrictions apply or capabilities must be supported by clients. Violations will result in the server closing the connection abnormally, or your web socket client interface behaving improperly and crashing:

-   No WebSocket frame over 131076 bytes in length will originate from the service
-   The server will not accept WebSocket frames over 131076 bytes. It may disconnect clients that do this
-   Websocket frames may be sent to clients up to 131076 bytes in length
-   WebSocket frames of up to 131076 bytes in length may be sent to clients.
    -   The other peer tunnel client may not construct a frame of this size, but the service may aggregate data and reconstruct frames of different sizes
-   The service will respond to WebSocket ping frames with a pong reply and a payload copy of the original ping payload
    -   The local proxy reference implementation uses this to measure server response latency
    -   Clients may need to send pings to keep connections alive
    -   It is not an error for the proxy server to not respond to a ping frame within any time frame, or at all
-   Pong frames sent to the service will not illicit a response
-   Ping/pong frames received by the service are included in bandwidth consumption for traffic rate limiting
-   The server will not initiate ping requests to clients, but clients should send a pong reply
-   The proxy server will not send text WebSocket frames. This protocol operates entirely with binary messages. If any text frames are received, clients SHOULD close the WebSocket connection

### Protocol behavior model: Tunneling data streams to TCP socket

The fundamental activity during tunneling is sending ProtocolBuffer messages back and forth carrying either data, or messages that manage the connection state (called _control messages_) over the websocket connection to the service. This websocket connection to the service, is synonymous with being connected to the tunnel. Once both peers are connected to a tunnel, the first thing that must happen is initiating a connection from source to destination. Using the local proxy, this would be when a client application connects to the listen port of the source mode local proxy. The source local proxy accepts the TCP connection and sends a _StreamStart_ message containing a unique identifier called the _stream ID_ to identify the connection and future messages associated with it.  On receiving a _StreamStart_ the destination local proxy side the tunnel will connect to a destination service listening on a port. If this operation succeeds, the destination local proxy must store the stream ID and validate messages originating from the tunnel peer. The destination local proxy does not send a reply to the source local proxy on successful connection. Immediately after the source local proxy sends _StreamStart_ and immediately after the destination establishes a valid TCP connection, each side respectively begins to process incoming messages, relaying valid data to the associated TCP connection it is connected to, or is connected to it. A data stream is ended by either side of the tunnel sending a _StreamReset_ control message with the currently stored stream ID associated with it regardless of if the TCP connection was closed normally or due to failure. Control messages associated with a stream are processed with the same stream ID filter, though some control messages may be associated whatever the active stream ID is (_SessionReset_)

Though there will be a reference chart about each of the message types and handling of data, here are some important things to know for a high-level understanding of tunneling data flow handling:

-   The service may use the stream ID to decide how to route traffic from connected tunnel clients.
-   The local proxy, and library clients MUST also use stream ID to determine how to respond to incoming messages.
    -   For example, if a source sends a _StreamStart_ with a stream ID of 345 in response to a newly accepted TCP connection, and afterwards receives a _Data_ message marked with stream ID 565, that data must be ignored
    -   Also, if a source sends a _StreamStart_ with a stream ID of 345 in response to a newly accepted TCP connection, and afterwards receives a _StreamReset_ message marked with stream ID 565, that message must be ignored
-   Ending a stream (normally or abnormally) is accomplished by either side sending a _StreamReset_ with the stream ID that is bieng closed
-   During a single websocket connection to a tunnel, multiple streams may be started and ended, but only one stream is supported at a time
-   Locally detected network failures are communicated by sending _StreamReset_ over the tunnel using the active stream ID if one is active.
    -   If the network issue is detected on the websocket connection, no control message is necessary to send. close the active data stream, then reconnect to the tunnel via the service and start a clean session

Following sections will go into further detail about this process:

### Tunneling message frames

Once a data transmission is possible, the sequence of WebSocket binary frames follow a simple framing structure: a **2-byte unsigned short, big endian** data length prefix, followed by sequence of bytes whose length is specified by the data length. These bytes must be parsed into a ProtocolBuffer message that uses the schema shown in this document. Every message received must be processed, and processed in order. The message may control the flow or state of the data stream, or it may contain stream data. Inspecting the message's type is the first step in processing a message. A single data length + bytes parsed into a ProtocolBuffers message represents an entire tunneling message frame, and the beginning of the next frame follows immediately. This is a visual diagram of a single frame:


    |-----------------------------------------------------------------|
    | 2-byte data length   |     N byte ProtocolBuffer message        |
    |-----------------------------------------------------------------|

Tunneling message frames are very loosely coupled with websocket frames. It is not required that a websocket frame contain an entire tunneling message frame. The start and end of a websocket frame does not have to be aligned with a tunneling frame and vice versa. A websocket frame may contain multiple tunneling frames, or it may contain only a slice of a tunneling frame started in a previous websocket frame and will finish in a later websocket frame. This means that processing the websocket data must be done as pure a sequence of bytes that sequentially construct tunneling frames regardless of what the websocket fragmentation is.

Additionally, the websocket framing decided by one tunnel client is not guaranteed to be the same as those received by the other side. For example, the maximum websocket frame size in the `aws.iot.securetunneling-1.0` protocol is 131076 bytes, and the service may aggregate data to a point that aggregates multiple messages to this size into a single frame.

### Protobuf Message Format

The data that must be parsed into a ProtocolBuffers message conforms to the following schema 'Message' object:

```
syntax = "proto3";

package com.amazonaws.iot.securedtunneling;

option java_outer_classname = "Protobuf";
option optimize_for = LITE_RUNTIME;

message Message {
    Type    type         = 1;
    int32   streamId     = 2;
    bool    ignorable    = 3;
    bytes   payload      = 4;

    enum Type {
        UNKNOWN = 0;
        DATA = 1;
        STREAM_START = 2;
        STREAM_RESET = 3;
        SESSION_RESET = 4;
    }
}
```

Data supplied in tunneling frames must parse into a _Message_ and satisfy the following rules:

-   _Type_ field must be set to a non-zero mapped enum value. Due to ProtocolBuffers schema recommendation, the keyword 'required' is not used in the actual schema
-   It is invalid for a client connected with mode=destination to send a message with _Type_ = _StreamStart_ over the tunnel.
-   It is invalid for any client to send messages types associated with a stream (_StreamStart_, _Data_, _StreamReset_) with a stream ID of 0
-   It is invalid for any client to send _SessionClose_
-   Payload may not contain more than 63kb (64512 bytes) of data.
-   Do not extend the schema with additional fields and send them through the tunnel. The service will close the websocket connection if this occurs
-   It is strongly recommended to not use negative stream ID numbers. Stream ID of 0 is invalid

### Message type handling reference

#### StreamStart

* _StreamStart_ is the first message sent to start and establish the new and active stream. For local proxies, this message carries across similar meaning to a TCP SYN packet.
* When to send
    * When the source tunnel client wants to initiate a new data stream with the destination it does this by sending a StreamStart with a temporally unique stream ID. Stream ID should be chosen in a way that doesn't repeat the same value quickly. In certain situations, if multiple (erroneous) clients are connecting to a tunnel and attempting to initiate streams and send data, stream ID uniqueness can prevent data stream corruption of what would otherwise be a successful reconnect.
* Behavior on receive:
    * Destination mode tunnel clients should treat this as a request to initiate a new stream to the statically configured destination service and establish the given stream ID as current
        * If the destination mode tunnel client already has an already open/active stream and receives a _StreamStart_, it must consider the current active stream to have closed and immediately start a new active stream with the new stream ID.
            * If the stream ID has changed, a StreamReset MAY be sent for the replaced stream ID
            * If the stream ID has not changed in this scenario, a StreamReset MUST NOT be sent
    * Source mode tunnel clients SHOULD treat receiving _StreamStart_ as an error and close the active data stream and websocket connection
* Notes
    * After the source client sends _StreamStart_, it may immediately send request data and assume the destination will connect. Failure will result in a _StreamReset_ coming back, and success (with data response) results in receiving data on the stream ID
* Example: Message(type=STREAM_START, streamId=1)


#### StreamReset

* _StreamReset_ messages conveys to both tunnel client modes that the data stream has ended, either in error, or closed intentionally. It is also used if the attempt to establish a connection fails.

* When to send:
    * While processing a received message, if the work that the receiver has to do to cannot be accomplished and forces corruption of the stream (i.e. cannot forward data to TCP connection due to I/O error, cannot create new stream) a _StreamReset_ should be sent with the stream ID of the active or requested stream ID
    * During a stream's data transmission, if anything happens that makes it impossible to prevent the stream data from being handled or processed correctly or in order, a StreamReset should be sent with the active stream ID

* Behavior on receive:
    * Both tunnel client modes must respond to a _StreamReset_ message by closing the active data stream or connection when the stream ID is current
        * After closing the current stream, the current stream ID should be unset internally
        * The tunnel client SHOULD perform an orderly shutdown of the data stream or connection and flush relevant buffers before closing
    * If the receiver does not have an active stream, it is safe to ignore a _StreamReset_ message
* Notes
    * The proxy server may generate StreamReset messages
        * The other end of a tunnel client is replaced
        * An internal operational activity temporarily disrupts the internal routing for the tunnel in a way that cannot allow the stream to be resumed seamlessly
* Example: Message(type=STREAM_RESET, streamId=1)

#### SessionReset

* _SessionReset_ messages can only originate from Secure Tunneling service if an internal data transmission error is detected

* When to send:
    * N/A - tunnel client cannot originate this message.
* Behavior on receive:
    * This message should be handled the same as _StreamReset_ except that it carries no stream ID association so any active stream should be closed
* Notes
    * This message type should rarely be observed.

#### Data

* _Data_ messages carry a payload of bytes to write to the active data stream.
* When to send:
    * When a tunnel client reads data on the (non-websocket) data stream (e.g. the TCP connection for the local proxy), it must construct _Data_ messages with the sequence of bytes put into the payload - up to 63kb in size - and set the active stream ID on the message.
* Behavior on receive:
    * When a local proxy receives _Data_ messages, it must write the payload data directly to the (non-websocket) data stream

### Ignorable field

If a message is received and its type is unrecognized, and this field is set to true, it is ok for the tunnel client to ignore the message safely. The tunnel client MAY still treat it the unrecognized message as an error out of caution.

