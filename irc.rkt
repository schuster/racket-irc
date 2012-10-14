#lang racket/base
(require racket/tcp)

; send NICK jschuster_

(define-values (outgoing incoming) (tcp-connect "chat.freenode.net" 6667))

; "NICK jschuster_\r\n"
