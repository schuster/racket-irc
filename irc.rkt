#lang racket/base

(require racket/string)
(require racket/tcp)


(provide irc-get-connection
         irc-connection-in-port ; TODO: remove this
         irc-send-command
	 irc-send-message
	 irc-join-channel
	 irc-connect
	 irc-set-nick
	 irc-set-user-info)

(struct irc-connection (in-port out-port))

(define (irc-get-connection host port)
  (let-values ([(in out) (tcp-connect host port)])
    (file-stream-buffer-mode out 'line)    
    (irc-connection in out)))

(define (irc-send-command connection command . parameters)
  (fprintf (irc-connection-out-port connection)
           "~a ~a\r\n"
           command
           (string-join parameters)))

(define (irc-set-nick connection nick)
  (irc-send-command connection "NICK" "rackirc"))

(define (irc-set-user-info connection nick real-name)
  (irc-send-command connection
		    "USER"
		    nick
		    "0"
		    "*"
		    (string-append ":" real-name)))

(define (irc-connect server port nick real-name)
  (define-values (in out) (tcp-connect server port))
  (file-stream-buffer-mode out 'line)    
  (define connection (irc-connection in out))
  (irc-set-nick connection nick)
  (irc-set-user-info connection nick real-name)
  connection)

(define (irc-join-channel connection channel)
  (irc-send-command connection "JOIN" channel))

(define (irc-send-message connection target message)
  (irc-send-command connection
		    "PRIVMSG"
		    target
		    (string-append ":" message)))
