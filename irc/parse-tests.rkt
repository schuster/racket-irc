#lang racket/base

(require "main.rkt")

(define (pm m)
  (printf "~a|~a|~s\n" (irc-message-prefix m) (irc-message-command m) (irc-message-parameters m)))

(pm (parse-message ":my-prefix my-command arg1 arg2 arg3"))

(pm (parse-message ":my-prefix my-command arg1 arg2 arg3 :2 2434 342"))

(pm (parse-message ":my-prefix my-command arg1 arg2 arg3 :4  5 6 7 8 9 0 1 2 3 4 5 6"))

(pm (parse-message ":my-prefix my-command arg1 arg2 arg3 4 5 6 7 8 9 0 1 2 3 4 5"))

(pm (parse-message "my-command arg1 arg2 arg3 4 5 6 7 8 9 0 1 2 3 4 5 6"))

(pm (parse-message "my-command arg1 arg2 arg3 4 :5 6 7 8 9 0 1 2 3 4 5 6"))

(printf "~s\n" (parse-message ""))

(printf "~s\n" (parse-message "   "))

(printf "~a\n" (parse-message ":something  "))
