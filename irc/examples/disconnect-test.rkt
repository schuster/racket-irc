#lang racket

;; Connects, joins a channel, and disconnects soon after to check for any errors on disconnecting

(require irc
         racket/async-channel)

(define-values (conn ready)
  (irc-connect "chat.freenode.net" 6667 "rackbot" "rbot" "Racket Bot" #:return-eof #t))

(sync ready)

(irc-join-channel conn "##racketirctest")

(define incoming (irc-connection-incoming conn))

(thread (lambda () (sleep 15) (irc-quit conn)))

(let loop ()
  (define next-msg (async-channel-get incoming))
  (printf "msg: ~s\n" next-msg)
  (unless (eof-object? next-msg) (loop)))
