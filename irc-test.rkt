#lang racket

(require "irc.rkt")
(require racket/gui/base)

(define window-frame (new frame% [label "IRC Test Client"]))
(define output-area (new editor-canvas% [parent window-frame]
			                [editor (new text%)]
					[min-width 800]
					[min-height 400]))

(define button (new button%
		    [parent window-frame]
		    [label "Send"]
		    [callback
		     (lambda (b e)
		       (irc-send-message
			connection
			"##racketirctest"
			(send input-field get-value))
		       (send input-field set-value ""))]))

(define input-field (new text-field%
			 [label "Message"]
			 [parent window-frame]
			 [min-width 200]))
			 

(define (add-text t)
  (send (send output-area get-editor) insert t))

(send window-frame show #t)

(define connection (irc-connect "chat.freenode.net" 6667 "rackirc" "Racket Test Client"))

(define reader-thread
  (thread (lambda ()
	    (define incoming (irc-connection-in-port connection))
	    (irc-join-channel connection "##racketirctest")
	    (irc-send-message connection "##racketirctest" "Hello")

          (let loop ()
            (define line (read-line incoming))
            (unless (eof-object? line)
	      (define raw-message (read-line incoming))
	      (add-text (string-append "Message: " raw-message "\n"))
              (display "Message: ")
              (display raw-message)
              (newline)
              (loop))))))

;;(thread-wait reader-thread)

; TODO: implement message send as the following, over some given connection
; (irc-send-message command parameter ... #:prefix prefix)
