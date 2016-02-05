#lang racket/base

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

;; ---------------------------------------------------------------------------------------------------

(require racket/async-channel
         racket/list
         racket/match
         racket/string
         racket/tcp
         openssl
         "private/numeric-replies.rkt")

(module+ test
  (require rackunit))

(struct irc-connection (in-port out-port in-channel handlers))
(struct irc-message (prefix command parameters content) #:transparent)

(define irc-connection-incoming irc-connection-in-channel)

(define (irc-get-connection host port
                            #:return-eof [return-eof #f]
                            #:ssl [ssl #f])
  (define-values (in out) (match ssl
                            [#f (tcp-connect host port)]
                            [#t (ssl-connect host port)]
                            [_ (ssl-connect host port ssl)]))
  (file-stream-buffer-mode out 'line)
  (define in-channel (make-async-channel))
  (define handlers (make-hash))
  (define connection (irc-connection in out in-channel handlers))
  (add-handler connection send-to-user)
  (add-handler connection handle-ping)

  (thread (lambda ()
            (let loop ()
              (sync in)
              (define line (if (port-closed? in) eof (read-line in)))
              (cond
               [(eof-object? line)
                (when return-eof
                  (async-channel-put in-channel line))]
               [else
                (define message (parse-message line))
                (when message
                  ;; convert to list here so that we can remove hash table elements during the loop
                  (for ([kv (hash->list (irc-connection-handlers connection))])
                    ((cdr kv) message connection (car kv))))
                (loop)]))))
  connection)

(define (irc-send-command connection command . parameters)
  (fprintf (irc-connection-out-port connection)
           "~a ~a\r\n"
           command
           (string-join parameters)))

(define (add-handler connection callback)
  (hash-set! (irc-connection-handlers connection) (gensym) callback))

(define (remove-handler connection handler-id)
  (hash-remove! (irc-connection-handlers connection) handler-id))

(define (send-to-user message connection handler-key)
  (async-channel-put (irc-connection-in-channel connection) message))

(define (handle-ping message connection handler-key)
  (match message
    [(irc-message _ "PING" params _)
     (irc-send-command connection "PONG" "pongresponse")]
    [_ (void)]))

(define (irc-set-nick connection nick)
  (irc-send-command connection "NICK" nick))

(define (irc-set-user-info connection username real-name)
  (irc-send-command connection
                    "USER"
                    username
                    "0"
                    "*"
                    (string-append ":" real-name)))


;; Connects to an IRC server, returning the connection and an event that will be ready for
;; synchronization when the server is ready for more commands
(define (irc-connect server port nick username real-name #:return-eof [return-eof #f] #:ssl [ssl #f])
  (define connection (irc-get-connection server port #:return-eof return-eof #:ssl ssl))
  (define sema (make-semaphore))
  (add-handler connection (listen-for-connect sema))
  (irc-set-nick connection nick)
  (irc-set-user-info connection username real-name)
  (values connection sema))

(define ((listen-for-connect sema) message connection handler-id)
  (match message
    [(irc-message _ RPL_WELCOME _ _)
     (semaphore-post sema)
     (remove-handler connection handler-id)]
    [_ (void)]))

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
  (define parts (string-split message " " #:trim? #f))
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
  (define s1-prefix (if (= 0 (string-length s1)) "" (substring s1 0 (string-length s2))))
  (equal? s1-prefix s2))

(module+ test
  (check-true (string-starts-with? "ab" "a"))
  (check-false (string-starts-with? "" "a")))

;; Run these via ``raco test main.rkt''
(module+ test
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
               (list "arg1" "arg2" "arg3" "4  5 6 7 8 9 0 1 2 3 4 5 6"))
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
               (list "arg1" "arg2" "arg3" "4" "5 6 7 8 9 0 1 2 3 4 5 6")))
