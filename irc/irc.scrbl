#lang scribble/manual

@(require (for-label racket
                     "main.rkt"))

@title{IRC Client Library}

@defmodule{irc}

@;; TODO: make IRC a code thing
The irc library allows you to develop an IRC client and communicate across IRC.

@section{Quick Start}

To use the IRC client library, you must first create a connection with @racket[irc-connect]. For example, to connect to the server my-server.org on port 1234 with nickname "fred" and real name "Fred Smith", do @racket[(irc-connect "my-server-org" 1234 "fred" "Fred Smith")]. This returns an @racket[irc-connection] object which must be used for all future communication with this server.

Once you have a connection, you can use other IRC commands. For example, if you have a connection object named @racket[connection], you can join a channel with

@racket[(irc-join connection "#some-channel")]

Once you have joined, you can send a message on that channel with the following:

@racket[(irc-send connection "#some-channel" "Hello, world!")]

@section{Data Structures}

@defstruct*[irc-raw-message ([content string?])]{
  Represents the raw response received from the server, before parsing. The raw message may be returned as a response if parsing failed.}

@defstruct*[(irc-message irc-raw-message)
            ([prefix (or/c string? #f)]
             [command string?]
             [parameters (listof string?)])]{
  The response received from the server, parsed into the @racket[prefix], @racket[command], and @racket[parameters]. If there is no prefix, @racket[prefix] is @racket[#f].}

@section{Procedures}

@defproc[(irc-connect [server string?]
                      [port (and/c exact-nonnegative-integer?
                                   (integer-in 1 65535))]
                      [nick string?]
                      [real-name string?])
          irc-connection?]{
  Connects to @racket[server] on @racket[port] using @racket[nick] as the IRC nickname and @racket[real-name] as the user's real name.}

@defproc[(irc-connection-in-channel [connection irc-connection?])
         async-channel?]{
  Returns the channel for incoming messages on the given connection. All responses from the server are sent to this channel, and will be a @racket[irc-raw-message] or one of its subtypes.}

@defproc[(irc-join-channel [connection irc-connection?]
                           [channel string?])
         void?]{
  Joins the IRC channel @racket[channel].}

@defproc[(irc-send-message [connection irc-connection?]
                           [target string?]
                           [message string?])
         void?]{
  Sends @racket[message] to @racket[target]. @racket[target] should be either a channel name or an IRC nick.}
