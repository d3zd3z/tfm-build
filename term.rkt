#! /usr/bin/env racket

#lang racket

;;; Run picocom as we can, and rerun when it disconnects, once the
;;; device comes back.
(define *device* "/dev/ttyACM0")

(let loop ()
  (let wait ()
    (unless (file-exists? *device*)
      (sleep 0.5)
      (wait)))
  (system* (find-executable-path "picocom")
	   "-e" "o" "-b" "115200" *device*)
  (loop))
