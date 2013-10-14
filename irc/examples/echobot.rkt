#lang racket

(require racket/async-channel)
(require irc)

(define-values (connection ready-event)
  (irc-connect "chat.freenode.net" 6667 "schubot" "schubot" "Schuster's Echo Bot"))
(void (sync ready-event))

(irc-join-channel connection "##racketirctest")
(define incoming (irc-connection-incoming connection))

(let loop ()
  (define message (async-channel-get incoming))
  (match message
    [(irc-message prefix "PRIVMSG" params _)
     (define prefix-match (regexp-match #rx"^[^!]+" prefix))
     (define message-match (regexp-match #rx"schubot: (.*)" (second params)))
     (when (and prefix-match message-match)
       (irc-send-message connection "##racketirctest"
                         (string-append (first prefix-match) ": " (second message-match))))]
    [_ (void)])
  (loop))
