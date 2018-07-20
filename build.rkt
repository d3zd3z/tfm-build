#! /usr/bin/env racket

#lang racket

;; Execution doesn't work if this isn't set.  Otherwise Racket tries to monitor the cmake/ninja/make
;; children, with horrible results.
; (subprocess-group-enabled #t)

(require "util/script.rkt")

(define *build-dir* (normalize-path "_build"))
(define *tfm-build-dir* (build-path *build-dir* "tfm"))
(define *tfm-source* (normalize-path "tf-m"))
(define *zephyr-dir* (normalize-path "zephyr"))
(define *zephyr-app-src* (build-path *zephyr-dir* "samples/v8m-test"))
(define *zephyr-build-dir* (build-path *build-dir* "zephyr"))
(define *out-dir* (normalize-path "out"))

;; Configuration for signatures
(define *tfm-part-layout* (build-path *tfm-source*
				      "platform/ext/target/musca_a/partition/flash_layout.h"))
(define *bin-tfm* (build-path *tfm-build-dir*
			      "app/secure_fw/tfm_s.bin"))
(define *bin-zephyr* (build-path *zephyr-build-dir*
				 "zephyr/zephyr.bin"))
(define *bin-mcuboot* (build-path *tfm-build-dir*
				  "bl2/ext/mcuboot/mcuboot.bin"))
(define *bin-sns-unsigned* (build-path *out-dir* "sns_unsigned.bin"))
(define *bin-sns-signed* (build-path *out-dir* "signed.bin"))
(define *hex-flashable* (build-path *out-dir* "musca_firmware.hex"))
(define *tfm-scripts* (build-path *tfm-source* "bl2/ext/mcuboot/scripts"))
(define *tfm-sign-cert* (build-path *tfm-source*
				    "bl2/ext/mcuboot/root-rsa-2048.pem"))

(define cmake-exe (find-executable-path "cmake"))
(define make-exe (find-executable-path "make"))
(define ninja-exe (find-executable-path "ninja"))
(define python3-exe (find-executable-path "python3"))
(define srec-cat-exe (find-executable-path "srec_cat"))
(define run-exe (normalize-path "./run"))

;;; Set up all of the directories useful for building.
(define (setup)
  (make-directory* *tfm-build-dir*)
  (make-directory* *zephyr-build-dir*)
  (make-directory* *out-dir*))

;;; Build TFM.
(define (cmake-tfm)
  (parameterize ([current-directory *tfm-build-dir*])
    (define regression (normalize-path (build-path *tfm-source* "ConfigRegression.cmake")))
    (check-system* run-exe
		   cmake-exe
		   "-GUnix Makefiles"
		   ;; "--trace-expand"
		   ;; "-GNinja"
		   (format "-DPROJ_CONFIG=~a" regression)
		   "-DTARGET_PLATFORM=MUSCA_A"
		   "-DCOMPILER=ARMCLANG"
		   "-DCMAKE_BUILD_TYPE=Debug"
		   *tfm-source*)
    (check-system* "/bin/ls")))

;;; Build the TFM.
(define (build-tfm)
  (parameterize ([current-directory *tfm-build-dir*])
    (check-system* run-exe
		   make-exe
		   "-j8")
    ;; Ugh, this fails, but has to run the first part.
    (system* run-exe make-exe "install")
    (printf "*** Ignoring above make error~%")))

;;; Make sure the links are in place in the sample app directory.
(define (ensure-symlinks)
  (make-symlink
    (normalize-path (build-path *tfm-build-dir* "install/tfm"))
    (build-path *zephyr-app-src* "ext")))

(define (build-zephyr)
  (parameterize ([current-directory *zephyr-build-dir*])
    (check-system* run-exe
		   cmake-exe
		   "-GNinja"
		   "-DBOARD=v2m_musca"
		   *zephyr-app-src*)
    (check-system* run-exe ninja-exe))) 

(define (sign-files)
  (check-system* run-exe
		 python3-exe
		 (build-path *tfm-scripts* "assemble.py")
		 "-l"
		 *tfm-part-layout*
		 "-s"
		 *bin-tfm*
		 "-n"
		 *bin-zephyr*
		 "-o"
		 *bin-sns-unsigned*)
  (check-system* run-exe
		 python3-exe
		 (build-path *tfm-scripts* "imgtool.py")
		 "sign" "-k" *tfm-sign-cert*
		 "--align" "1"
		 "-v" "1.0"
		 "-H" "0x400"
		 "--pad" "0x30000"
		 *bin-sns-unsigned*
		 *bin-sns-signed*)

  (check-system* run-exe
		 srec-cat-exe
		 *bin-mcuboot* "-Binary" "-offset" "0x200000"
		 *bin-sns-signed* "-Binary" "-offset" "0x210000"
		 "-o" *hex-flashable* "-Intel"))

;;; TODO: Collect timestamps from TFM sources (CMSIS and mbedlts as
;;; well), and avoid compilation if all sources are unchanged.

;;; Run it all.
(module+ main
  (setup)
  (cmake-tfm)
  (build-tfm)
  (ensure-symlinks)
  (build-zephyr)
  (sign-files))
