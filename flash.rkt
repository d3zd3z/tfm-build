#! /usr/bin/env racket

#lang racket

(require "util/script.rkt")

(define dev-path "/dev/disk/by-id")

(define sudo-exe (must-find-executable "sudo"))
(define mount-exe (must-find-executable "mount"))
(define umount-exe (must-find-executable "umount"))
(define cp-exe (must-find-executable "cp"))
(define sync-exe (must-find-executable "sync"))

(define firmware "out/musca_firmware.hex")
(define mount-dir "/mnt/tmp")

(define (with-mounted dev path action)
  (dynamic-wind
    (lambda ()
      (check-system* sudo-exe mount-exe dev path))
    action
    (lambda ()
      (check-system* sudo-exe umount-exe path))))

;;; Try to find the mbed device.  Returns the first path that matches
;;; the expression.
(define (find-mbed)
  (define name (for/or ([name (directory-list dev-path)])
		 (and (regexp-match? #rx"^usb-MBED_VFS" name) name)))
  (unless name
    (error "Unable to find mbed device, is it connected?"))
  (normalize-path (build-path dev-path name)))

;;; After mounting, verify the existence of "MBED.HTM".  If it isn't
;;; present, we might be talking with the firmware image instead, and
;;; should abort.  This probably isn't necessary, since the
;;; "usb-MBED_VSF" won't be present.
(define (verify-mbed mountdir)
  (unless (file-exists? (build-path mountdir "MBED.HTM"))
    (error "MBED.HTM not present, possibly in firmware mode")))

(let ([device (find-mbed)])
  (with-mounted
    device mount-dir
    (lambda ()
      (check-system* (must-find-executable "ls") "-l" mount-dir)
      (verify-mbed mount-dir)
      (check-system* sudo-exe cp-exe firmware mount-dir)

      (printf "Waiting for data to be written~%")
      (time (check-system* sync-exe))

      (check-system* (must-find-executable "ls") "-l" mount-dir)
      )))
