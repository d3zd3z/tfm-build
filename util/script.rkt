#lang racket

;;; Utilities for scripting

(provide must-find-executable
	 check-system*
	 make-symlink
	 trace-commands)

(define rm-exe (find-executable-path "rm"))

(define trace-commands (make-parameter #t))

(define (must-find-executable name)
  (or (find-executable-path name)
      (error "Unable to find program on path" name)))

;;; Like system*, but throws an exception if there is an error.
(define (check-system* . args)
  (when (trace-commands)
    (printf "run: ~a~%" args))
  (or (apply system* args)
      (error "Error running" args)))

;;; Create a symlink.
(define (make-symlink src dest)
  ;; Make sure the directory exists
  (define path-part (path-only dest))
  (when (and path-part
	     (not (directory-exists? path-part)))
    (make-directory* path-part))

  ;; Remove and create the symlink.  Unfortunately, it is hard to know if a file exists in racket,
  ;; so we'll just call out to 'rm' and ignore the result.
  ;; TODO: Ignore the error within racket.
  (call-with-output-file
    "/dev/null" #:exists 'append
    (lambda (dev-null)
      (parameterize ([current-error-port dev-null])
	(system* rm-exe dest))))
  (make-file-or-directory-link src dest))

