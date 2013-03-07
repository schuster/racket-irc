#lang racket

(require "main.rkt")
(require racket/async-channel)
(require racket/gui/base)

(define window-frame (new frame% [label "IRC Test Client"]))
(define channel-selector (new choice%
                              [parent window-frame]
                              [label "Channel"]
                              [choices (list "Messages")]
                              [callback (lambda (c e) (switch-channel))]))

(define output-area (new editor-canvas% [parent window-frame]
			                [editor (new text% [auto-wrap #t])]
					[min-width 800]
					[min-height 400]))

(define button (new button%
		    [parent window-frame]
		    [label "Send"]
		    [callback (lambda (b e) (handle-input))]))

(define input-field (new text-field%
			 [label "Message"]
			 [parent window-frame]
			 [min-width 200]))

(define (add-text t)
  (send (send output-area get-editor) insert t))

(define (switch-channel)
  (define channel (send channel-selector get-string-selection))
  (set! current-window channel)
  (refresh-messages))

(define (refresh-messages)
  (define editor (send output-area get-editor))
  (send editor erase)
  (send editor insert (hash-ref window-texts current-window)))

(define window-texts (make-hash))
(hash-set! window-texts "Messages" "")
(define current-window "Messages")

(send window-frame show #t)

(define (string-starts-with? s1 s2)
  (and (>= (string-length s1) (string-length s2))
       (equal? s2 (substring s1 0 (string-length s2)))))

(define (handle-input)
  (define message (send input-field get-value))
  (cond [(string-starts-with? message "/join")
         (define channel-name (substring message 6))
         (irc-join-channel connection channel-name)
         (hash-set! window-texts channel-name "")
         (send channel-selector append channel-name)]
        [(irc-send-message
          connection
          current-window
          message)])
  (send input-field set-value ""))



(define connection (irc-connect "chat.freenode.net" 6667 "rackirc" "Racket Test Client"))

(define reader-thread
  (thread (lambda ()
	    (define incoming (irc-connection-in-channel connection))

            (let loop ()
              (define message (async-channel-get incoming))
              (match message
                [(? irc-message?)
                 (define msg-to-print (format "Prefix: ~a, CMD: ~a, params: ~a\n"
                                              (irc-message-prefix message)
                                              (irc-message-command message)
                                              (irc-message-parameters message)))
                 (printf "~a\n" msg-to-print)
                 (hash-set! window-texts current-window
                            (string-append (hash-ref window-texts current-window) "\n" msg-to-print))]
                [_ (printf "unparsable: ~a\n" (irc-raw-message-content message))])
              (refresh-messages)
              (loop)))))

#;(irc-join-channel connection "##racketirctest")
#;(irc-send-message connection "##racketirctest" "Hello")

;;(thread-wait reader-thread)

; TODO: implement message send as the following, over some given connection
; (irc-send-message command parameter ... #:prefix prefix)
