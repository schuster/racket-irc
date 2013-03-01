#lang racket

(require racket/async-channel)
(require "irc.rkt")

(define connection (irc-connect "chat.freenode.net" 6667 "schubot" "Schuster's Echo Bot"))
(sleep 5)

(irc-join-channel connection "##racketirctest")
(define incoming (irc-connection-in-channel connection))

(let loop ()
  (define message (async-channel-get incoming))
  (match message
    [(irc-message _ #f _ _) (void)]
    [(irc-message _ prefix "PRIVMSG" params)
     (define prefix-match (regexp-match #rx"^[^!]+" prefix))
     (define message-match (regexp-match #rx"schubot: (.*)" (second params)))
     (when (and prefix-match message-match)
       (irc-send-message connection "##racketirctest"
                         (string-append (first prefix-match) ": " (second message-match))))]
    [_ (void)])
  (loop))
