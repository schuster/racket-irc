#lang racket/base

(provide ctcp-action)

(require "main.rkt")

;; Translates a low-level to mid-level message (or maybe the other way around?)
(define (low-level-quote m)
  (define m-quote "\020")
  ; NUL -> m-quote 0
  ; newline -> m-quote n
  ; carriage return: m-quote r
  ; m-quote : mquote mquote
  (regexp-replaces m
                   `([,m-quote ,(string-append m-quote m-quote)]
                     ["\n" "\020n"]
                     ["r" "\020r"]
                     ["\000" "\0200"])))

;; TODO: define low-level-unquote

;; TODO: test low-level quote


(define x-delim "\001")

;; Character inside x-delimiter is \000 or \002-\377


;; Extended message: either:
;; * empty,
;; * sequence of one or more non-space (\040) characters, followed by optional single space + sequence of non-space characters

;; part before space is tag, after is data

;; extended data allowed only in privmsg and notice (always as privmsg unless in reply to another privmsg query)

;; there may be 0 or more extended messgaes in the privmsg, along with non-extended data

(define x-quote "\134")

(define (ctcp-level-quote m)
  (regexp-replaces m
                    `([,x-quote ,(string-append x-quote x-quote)]
                      [,x-delim ,(string-append x-quote "a")])))

(define (ctcp-action connection target action-message)
  (irc-send-message connection
                    target
                    (low-level-quote (string-append x-delim "ACTION " (ctcp-level-quote action-message) x-delim))))
