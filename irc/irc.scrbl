#lang scribble/manual

@(require (for-label racket/base
                     "main.rkt"))

@title{IRC Client Library}

@defmodule[irc]

@;; TODO: make IRC a code thing
The irc library allows you to develop IRC clients and communicate over IRC.

@section{Quick Start}

To use the IRC client library, first create a connection with @racket[irc-connect]. For example, to
connect to the Freenode (chat.freenode.net, port 6667) with nickname "rackbot", username "rbot", and real
name "Racket Bot", do

@racketblock[
(define-values (connection ready)
  (irc-connect "chat.freenode.net" 6667 "rackbot" "rbot" "Racket Bot"))]

This defines an @racket[irc-connection] object which must be used for all future communication with
this server, as well as an event that will be ready for synchronization when the server is ready to
accept more commands (i.e. when the connection has been fully established).

Once the returned event fires, you can use other IRC commands. For example, if you have a connection
object named @racket[connection], you can join the #racket channel with

@racket[(irc-join-channel connection "#racket")]

Once you have joined, you can send a message on that channel with the following:

@racket[(irc-send-message connection "#racket" "Hello, world!")]

@section{Data Structures}

@defstruct*[irc-message
            ([prefix (or/c string? #f)]
             [command string?]
             [parameters (listof string?)]
             [content string?])]{

  Represents an IRC message, parsed into the @racket[prefix], @racket[command], and
  @racket[parameters]. If the message did not contain a prefix, @racket[prefix] is @racket[#f]. The
  original raw message line is available in the @racket[content] field.}

@section{Procedures}

@defproc[(irc-connection? [object any])
         boolean?]{

  Returns true if the given object is an IRC connection; false otherwise.}

@defproc[(irc-connect [server string?]
                      [port (and/c exact-nonnegative-integer?
                                   (integer-in 1 65535))]
                      [nick string?]
                      [username string?]
                      [real-name string?]
                      [#:return-eof return-eof boolean? #f]
                      [#:ssl ssl (or/c ssl-client-context? 'auto 'sslv2-or-v3 'sslv2 'sslv3 'tls 'tls11 'tls12 boolean?) #f])
          (values irc-connection? evt?)]{

  Connects to @racket[server] on @racket[port] using @racket[nick] as the IRC nickname,
  @racket[username] as the username, and @racket[real-name] as the user's real name. Returns a
  connection object and an event that will be ready for synchronization when the server is ready to
  accept more commands. If @racket[return-eof] is @racket[#t], the incoming stream will include an
  end-of-file whenever the underlying TCP stream receives one (e.g. if the connection fails).
  If @racket[ssl] is not @racket[#f] the connection will be made over SSL/TLS with the appropriate
  SSL/TLS mode or client context.}

@defproc[(irc-connection-incoming [connection irc-connection?])
         async-channel?]{

  Returns the channel for incoming messages on the given connection. All responses from the server are
  sent to this channel, and will be an @racket[irc-message] or one of its subtypes, or @racket[eof] if
  the server closes the connection and the @racket[return-eof] option was used when establishing the
  connection.}

@defproc[(irc-join-channel [connection irc-connection?]
                           [channel string?])
         void?]{

  Joins the IRC channel @racket[channel].}

@defproc[(irc-part-channel [connection irc-connection?]
                           [channel string?])
         void?]{

  Parts from (leaves) the IRC channel @racket[channel].}

@defproc[(irc-send-message [connection irc-connection?]
                           [target string?]
                           [message string?])
         void?]{

  Sends @racket[message] to @racket[target]. @racket[target] should be either a channel name or an IRC
  nick.}

@defproc[(irc-send-notice [connection irc-connection?]
                          [target string?]
                          [notice string?])
         void?]{

  Sends the notice @racket[notice] to @racket[target]. @racket[target] should be either a channel name
  or an IRC nick.}

@defproc[(irc-get-connection [host string?]
                             [port (and/c exact-nonnegative-integer?
                                   (integer-in 1 65535))]
                             [#:return-eof return-eof boolean? #f]
                             [#:ssl ssl (or/c ssl-client-context? 'auto 'sslv2-or-v3 'sslv2 'sslv3 'tls 'tls11 'tls12 boolean?) #f])
         irc-connection?]{

  Establishes a connection to the IRC server @racket[host] on the given @racket[port]. When
  @racket[return-eof] is @racket[#t], @racket[eof] will be returned over the incoming channel when the
  server closes the connection. If @racket[ssl] is not @racket[#f] the connection will be made over
  SSL/TLS with the appropriate SSL/TLS mode or client context.

  Use this form instead of @racket[irc-connect] when you want more control over when to send the NICK
  and USER commands.}

@defproc[(irc-set-nick [connection irc-connection?]
                       [nick string?])
         void?]{

  Sets the nickname for this connection to @racket[nick]. Note that @racket[irc-connect] runs this
  command for you when the connection is first established.}

@defproc[(irc-set-user-info [connection irc-connection?]
                            [username string?]
                            [real-name string?])
         void?]{

  Sets the user name and real name for this connection to @racket[username] and @racket[real-name],
  respectively . Note that @racket[irc-connect] runs this command for you when the connection is first
  established.}

@defproc[(irc-quit [connection irc-connection?]
                   [quit-message string? ""])
         void?]{

  Quits the IRC session with an optional @racket[quit-message] and closes the connection.}

@defproc[(irc-send-command [connection irc-connection?]
                           [command string?]
                           [args string?] ...)
         void?]{

  Sends the given IRC @racket[command] ands its @racket[args] over the given @racket[connection]. This
  is the most general method for sending commands to IRC, but the other functions described above
  should be preferred where applicable.}

@section{CTCP}

CTCP is an embeded protocol within IRC that allows for actions such as @code{/me} commands. This
package currently has basic support for CTCP

@defproc[(ctcp-action [connection irc-connection?]
                      [target string?]
                      [action string?])
         void?]{

  Sends the given action to the target, usually displayed in the channel as "<sender-nick> <action>"
  (i.e. the expected result of a @code{/me} command). @racket[target] should be either a channel name
  or an IRC nick.}

@section{Further Information}

For more information on the IRC client protocol, see @hyperlink["http://tools.ietf.org/html/rfc2812" "RFC 2812"].
