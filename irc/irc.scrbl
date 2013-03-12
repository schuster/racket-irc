#lang scribble/manual

@title{IRC Client Library}

@;; TODO: make IRC a code thing
The irc library allows you to develop an IRC client and communicate across IRC.

@section{Quick Start}

To get a connection, use @racket[irc-connect]. For example, to connect to the server my-server.org on port 1234 with nickname "fred" and real name "Fred Smith", do @racket[(irc-connect "my-server-org" 1234 "fred" "Fred Smith")]. This returns an irc-connection object which must be used for all future communication with this server. For example, if you have a connection object named connection, you can join a channel with

(irc-join connection "#some-channel")

Then you can send a message on that channel like so:

(irc-send connection "#some-channel" "Hello, world!")
