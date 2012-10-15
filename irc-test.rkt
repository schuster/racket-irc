#lang racket

(require "irc.rkt")

(define connection (irc-get-connection "chat.freenode.net" 6667))
(define incoming (irc-connection-in-port connection))

(define reader-thread
  (thread (lambda ()
          (let loop ()
            (define line (read-line incoming))
            (unless (eof-object? line)
              (display "Message: ")
              (display (read-line incoming))
              (newline)
              (loop))))))

(irc-send-command connection "NICK" "rackirc")
(irc-send-command connection "USER" "rackirc" "0" "*" ":TesterSchu")
(irc-send-command connection "JOIN" "##racketirctest")
(irc-send-command connection "PRIVMSG" "##racketirctest" ":Hello, world")

(thread-wait reader-thread)

; TODO: implement message send as the following, over some given connection
; (irc-send-message command parameter ... #:prefix prefix)
