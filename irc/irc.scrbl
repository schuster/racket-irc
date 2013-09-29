#lang scribble/manual

@(require (for-label racket
                     "main.rkt"))

@title{IRC Client Library}

@defmodule[irc]

@;; TODO: make IRC a code thing
The irc library allows you to develop an IRC client and communicate across IRC.

@section{Quick Start}

To use the IRC client library, first create a connection with @racket[irc-connect]. For example, to connect to the server my-server.org on port 1234 with nickname "fred", username "fred", and real name "Fred Smith", do @racket[(irc-connect "my-server-org" 1234 "fred" "fred" "Fred Smith")]. This returns an @racket[irc-connection] object which must be used for all future communication with this server, as well as an event that will be ready for synchronization when the server is ready to accept more commands (i.e. when the connection has been fully established).

Once the returned event fires, you can use other IRC commands. For example, if you have a connection object named @racket[connection], you can join a channel with

@racket[(irc-join connection "#some-channel")]

Once you have joined, you can send a message on that channel with the following:

@racket[(irc-send connection "#some-channel" "Hello, world!")]

@section{Data Structures}

@defstruct*[(irc-message irc-raw-message)
            ([prefix (or/c string? #f)]
             [command string?]
             [parameters (listof string?)])]{
  Represents an IRC message, parsed into the @racket[prefix], @racket[command], and @racket[parameters]. If there is no prefix, @racket[prefix] is @racket[#f]. The original message line is available in the @racket[content] field. }

@section{Procedures}

@defproc[(irc-connection? [object any])
         boolean?]{
  Returns true if the given object is an IRC connection; false otherwise.}

@defproc[(irc-connect [server string?]
                      [port (and/c exact-nonnegative-integer?
                                   (integer-in 1 65535))]
                      [nick string?]
                      [real-name string?])
          (values irc-connection? evt?)]{
  Connects to @racket[server] on @racket[port] using @racket[nick] as the IRC nickname, @racket[username] as the username, and @racket[real-name] as the user's real name. Returns a connection object and an event that will be ready for synchronization when the server is ready to accept more commands.}

@defproc[(irc-connection-incoming [connection irc-connection?])
         async-channel?]{
  Returns the channel for incoming messages on the given connection. All responses from the server are sent to this channel, and will be an @racket[irc-raw-message] or one of its subtypes.}

@defproc[(irc-join-channel [connection irc-connection?]
                           [channel string?])
         void?]{
  Joins the IRC channel @racket[channel].}

@defproc[(irc-send-message [connection irc-connection?]
                           [target string?]
                           [message string?])
         void?]{
  Sends @racket[message] to @racket[target]. @racket[target] should be either a channel name or an IRC nick.}
