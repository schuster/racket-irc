#lang racket/base

(require racket/async-channel)
(require racket/list)
(require racket/match)
(require racket/string)
(require racket/tcp)

(provide irc-get-connection
         irc-connection-incoming
         irc-send-command
         irc-send-message
         irc-send-notice
         irc-join-channel
         irc-part-channel
         irc-connect
         irc-set-nick
         irc-set-user-info
         irc-quit
         irc-connection?
         (struct-out irc-message))

(struct irc-connection (in-port out-port in-channel))
(struct irc-message (prefix command parameters content) #:transparent)

(define irc-connection-incoming irc-connection-in-channel)

(define (irc-get-connection host port #:return-eof [return-eof #f])
  (define-values (in out) (tcp-connect host port))
  (file-stream-buffer-mode out 'line)
  (define in-channel (make-async-channel))
  (define connection (irc-connection in out in-channel))

  (thread (lambda ()
            (let loop ()
              (define line (read-line in))
              (cond
               [(eof-object? line)
                (when return-eof
                  (async-channel-put in-channel line))]
               [else
                (define message (parse-message line))
                (match message
                  [#f (void)]
                  [(irc-message _ "PING" params _)
                   (irc-send-command connection "PONG" "pongresponse")]
                  [_ (async-channel-put in-channel message)])
                (loop)]))))
  connection)

(define (irc-send-command connection command . parameters)
  (fprintf (irc-connection-out-port connection)
           "~a ~a\r\n"
           command
           (string-join parameters)))

(define (irc-set-nick connection nick)
  (irc-send-command connection "NICK" nick))

(define (irc-set-user-info connection username hostname server-name real-name)
  (irc-send-command connection
                    "USER"
                    username
                    hostname
                    server-name
                    (string-append ":" real-name)))

(define (irc-connect server port nick real-name)
  (define connection (irc-get-connection server port))
  (irc-set-nick connection nick)
  (irc-set-user-info connection nick real-name)
  connection)

(define (irc-join-channel connection channel)
  (irc-send-command connection "JOIN" channel))

(define (irc-part-channel connection channel)
  (irc-send-command connection "PART" channel))

(define (irc-send-message connection target message)
  (irc-send-command connection
		    "PRIVMSG"
		    target
		    (string-append ":" message)))

(define (irc-send-notice connection target message)
  (irc-send-command connection
                    "NOTICE"
                    target
                    (string-append ":" message)))

(define (irc-quit connection [quit-message ""])
  (if (string=? quit-message "")
      (irc-send-command connection "QUIT")
      (irc-send-command connection "QUIT" quit-message))
  (close-output-port (irc-connection-out-port connection))
  (close-input-port (irc-connection-in-port connection)))

;; Given the string of an IRC message, returns an irc-message that has been parsed as far as possible,
;; or #f if the input was unparsable
(define (parse-message message)
  (define parts (string-split message))
  (define prefix (if (and (pair? parts)
                          (string-starts-with? (list-ref parts 0) ":"))
                     (substring (list-ref parts 0) 1)
                     #f))
  (cond [(> (length parts) (if prefix 1 0))
         (define command (list-ref parts (if prefix 1 0)))
         (define param-parts (list-tail parts (if prefix 2 1)))
         (irc-message prefix command (parse-params param-parts) message)]
        [else #f]))

;; Given the list of param parts, return the list of params
(define (parse-params parts)
  (define first-tail-part (find-first-tail-part parts))
  (cond [first-tail-part
         (define tail-with-colon (string-join (list-tail parts first-tail-part)))
         (define tail-param (if (string-starts-with? tail-with-colon ":")
                                (substring tail-with-colon 1)
                                tail-with-colon))
         (append (take parts first-tail-part)
                 (list tail-param))]
        [else parts]))

;; Return the index of the first part that starts the tail parameters; of #f if no tail exists
(define (find-first-tail-part param-parts)
  (define first-colon-index (memf/index (lambda (v) (string-starts-with? v ":"))
                                        param-parts))
  (cond [(or first-colon-index (> (length param-parts) 14))
         (min 14 (if first-colon-index first-colon-index 14))]
        [else #f]))

;; Like memf, but returns the index of the first item to satisfy proc instead of
;; the list starting at that item.
(define (memf/index proc lst)
  (define memf-result (memf proc lst))
  (cond [memf-result (- (length lst) (length memf-result))]
        [else #f]))

(define (string-starts-with? s1 s2)
  (equal? (substring s1 0 (string-length s2))
          s2))

;; Run these via ``raco test main.rkt''
(module+ test
  (require rackunit)

  (define (message-equal? m1 m2)
    (and (equal? (irc-message-prefix m1) (irc-message-prefix m2))
         (equal? (irc-message-command m1) (irc-message-command m2))
         (equal? (irc-message-parameters m1) (irc-message-parameters m2))))

  (define-check (check-parse input expected-prefix expected-command expected-args)
    (let ([actual (parse-message input)]
          [expected (irc-message expected-prefix
                                 expected-command
                                 expected-args
                                 input)])
      (with-check-info*
       (list (make-check-actual actual)
             (make-check-expected expected))
       (lambda ()
         (when (not
                (message-equal?
                 actual
                 expected))
           (fail-check))))))

  (check-parse ":my-prefix my-command arg1 arg2 arg3"
               "my-prefix"
               "my-command"
               (list "arg1" "arg2" "arg3"))
  (check-parse ":my-prefix my-command arg1 arg2 arg3 :4  5 6 7 8 9 0 1 2 3 4 5 6"
               "my-prefix"
               "my-command"
               (list "arg1" "arg2" "arg3" "4 5 6 7 8 9 0 1 2 3 4 5 6"))
  (check-parse ":my-prefix my-command arg1 arg2 arg3 4 5 6 7 8 9 0 1 2 3 4 5"
               "my-prefix"
               "my-command"
               (list "arg1" "arg2" "arg3" "4" "5" "6" "7" "8" "9" "0" "1" "2" "3" "4" "5"))
  (check-parse "my-command arg1 arg2 arg3 4 5 6 7 8 9 0 1 2 3 4 5 6"
               #f
               "my-command"
               (list "arg1" "arg2" "arg3" "4" "5" "6" "7" "8" "9" "0" "1" "2" "3" "4" "5 6"))

  (check-parse "my-command arg1 arg2 arg3 4 :5 6 7 8 9 0 1 2 3 4 5 6"
               #f
               "my-command"
               (list "arg1" "arg2" "arg3" "4" "5 6 7 8 9 0 1 2 3 4 5 6"))
  )
