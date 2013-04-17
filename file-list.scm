;; -*- coding: utf-8 -*-
;;  Copyright (c) 2008 ENDO Yasuyuki, All rights reserved. 
;;  Copyright (c) 2008 Kahua Project, All rights reserved. 
;;  See COPYING for terms and conditions of using this software 

(use file.util)
(use srfi-1)
(use srfi-13)
(use util.list)
(use gauche.parameter)
(use gauche.parseopt)
(use text.tree)

(define *instdir* "$INSTDIR")
(define *ignore-path* '("CVS" ".svn"))
(define *target-prefix* "    SetOutPath ")
(define *install-prefix* "    File ")
(define *delete-prefix* "    Delete /REBOOTOK ")
(define *cr-lf* "\r\n")
(define *path-separater* "\\")
(define *file-list* (make-parameter #f))
(define *current-version* (make-parameter #f))

(define (replace-inst prefix path)
  (let* ([pre1 (regexp-replace-all #/\// prefix "\\\\")]
         [pre2 (regexp-replace-all #/\\/ pre1 "/")])
    (cond [(or (string-prefix? pre1 path)
               (string-prefix? pre2 path))
           (string-replace path *instdir* 0 (string-length pre1))]
          [else (error "Path prefix ~s does not match: ~a" prefix path)])))

;; NSIS requires version number to be X.X.X.X
(define (canonical-version version)
  (string-join (take* (string-split (regexp-replace #/[-_].+$/ version "") #\.)
                      4 #t "0")
               "."))

(define (file-list path)
  (directory-fold
   path cons '()
   :lister (lambda (path seed)
	     (receive (d f) (directory-list2 path :add-path? #t :children? #t)
	       (values d (acons path f seed))))))

(define (check-ignore-path str lis)
  (every (lambda (s) (not (string-contains str s))) lis))

(define (initialize dist-list version)
  (*current-version* (canonical-version version))
  (*file-list*
   (map (lambda (path)
          (cons path
                (reverse
                 (filter (lambda (ls)
                           (and (pair? (cdr ls))
                                (check-ignore-path (car ls) *ignore-path*)))
                         (file-list path)))))
        dist-list)))

(define (inst-str root-path ls)
  (cons
   #`",|*target-prefix*|,(change-path (replace-inst root-path (car ls))),|*cr-lf*|"
   (map change-path
	(map (lambda (s) #`",|*install-prefix*|,|s|,|*cr-lf*|") (cdr ls)))))

(define (del-str root-path ls)
  (map (lambda (s) #`",|*delete-prefix*|,(change-path (replace-inst root-path s)),|*cr-lf*|")
       (cdr ls)))

(define (install-files)
  (append-map (lambda (ls)
                (map (cute inst-str (sys-dirname (car ls)) <>) (cdr ls)))
              (*file-list*)))

(define (delete-files)
  (append-map (lambda (ls)
                (map (cute del-str (sys-dirname (car ls)) <>) (cdr ls)))
              (*file-list*)))

(define (include line)
  (or (and-let* ((match (#/^(.*)##\(include (.*)\)(.*\r\n)$/ line))
                 (exp (call-with-input-string (match 2) (cut read <>))))
        (list (match 1) (eval exp (current-module)) (match 3)))
      line))

(define (include-all lis) (map include lis))

(define (change-path str)
  (string-join (string-split str #\/) *path-separater*))

(define (read-line-crlf file)
  (let1 line (read-line file)
    (if (eof-object? line) line #`",|line|,|*cr-lf*|")))

(define (main args)
  (let1 path-list '()
    (let-args (cdr args)
	((path "p|path=s"
	       => (lambda (x) (push! path-list x)))
	 (template "t|template=s" #f)
	 (version "v|version=s" #f))
      (let* ((path-list (filter file-exists? path-list))
	     (out (path-sans-extension template))
	     (lines (file->list read-line-crlf template)))
        (initialize path-list version)
        (call-with-output-file out
          (cut write-tree (include-all lines) <>))
        0))))
