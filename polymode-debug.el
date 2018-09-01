;;; polymode-debug.el --- Interactive debugging utilities for polymode -*- lexical-binding: t -*-
;;
;; Copyright (C) 2016-2018 Vitalie Spinu
;; Author: Vitalie Spinu
;; URL: https://github.com/vspinu/polymode
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This file is *NOT* part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;

;;; Commentary:
;;

;;; Code:

(require 'polymode-core)
(require 'poly-lock)


;;; MINOR MODE

(defvar pm--underline-overlay
  (let ((overlay (make-overlay (point) (point))))
    (overlay-put overlay 'face  '(:underline (:color "tomato" :style wave)))
    overlay)
  "Overlay used in function `pm-debug-mode'.")

(defvar pm--highlight-overlay
  (let ((overlay (make-overlay (point) (point))))
    (overlay-put overlay 'face  '(:inverse-video t))
    overlay)
  "Overlay used by `pm-debug-map-over-spans-and-highlight'.")

(defvar pm-debug-minor-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "M-n M-i")     #'pm-debug-info-on-current-span)
    (define-key map (kbd "M-n i")       #'pm-debug-info-on-current-span)
    (define-key map (kbd "M-n M-p")     #'pm-debug-print-relevant-variables)
    (define-key map (kbd "M-n p")       #'pm-debug-print-relevant-variables)
    (define-key map (kbd "M-n M-h")     #'pm-debug-map-over-spans-and-highlight)
    (define-key map (kbd "M-n h")       #'pm-debug-map-over-spans-and-highlight)

    (define-key map (kbd "M-n M-t i")   #'pm-debug-toogle-info-message)
    (define-key map (kbd "M-n M-t f")   #'pm-debug-toggle-fontification)
    (define-key map (kbd "M-n M-t p")   #'pm-debug-toggle-post-command)
    (define-key map (kbd "M-n M-t c")   #'pm-debug-toggle-after-change)
    (define-key map (kbd "M-n M-t a")   #'pm-debug-toggle-all)
    (define-key map (kbd "M-n M-t v")   #'pm-debug-toggle-verbose)
    (define-key map (kbd "M-n M-t s")   #'pm-debug-toggle-verbose-syntax)
    (define-key map (kbd "M-n M-t M-i")   #'pm-debug-toogle-info-message)
    (define-key map (kbd "M-n M-t M-f")   #'pm-debug-toggle-fontification)
    (define-key map (kbd "M-n M-t M-p")   #'pm-debug-toggle-post-command)
    (define-key map (kbd "M-n M-t M-c")   #'pm-debug-toggle-after-change)
    (define-key map (kbd "M-n M-t M-a")   #'pm-debug-toggle-all)
    (define-key map (kbd "M-n M-t M-v")   #'pm-debug-toggle-verbose)
    (define-key map (kbd "M-n M-t M-s")   #'pm-debug-toggle-verbose-syntax)
    (define-key map (kbd "M-n M-f t")   #'pm-debug-toggle-fontification)
    (define-key map (kbd "M-n M-f s")   #'pm-debug-fontify-current-span)
    (define-key map (kbd "M-n M-f b")   #'pm-debug-fontify-current-buffer)
    (define-key map (kbd "M-n M-f M-t")   #'pm-debug-toggle-fontification)
    (define-key map (kbd "M-n M-f M-s")   #'pm-debug-fontify-current-span)
    (define-key map (kbd "M-n M-f M-b")   #'pm-debug-fontify-current-buffer)
    map))

(define-minor-mode pm-debug-minor-mode
  "Turns on/off useful facilities for debugging polymode.

Key bindings:
\\{pm-debug-minor-mode-map}"
  nil
  " PMDBG"
  :group 'polymode
  (if pm-debug-minor-mode
      (progn
        ;; this is global hook. No need to complicate with local hooks
        (add-hook 'post-command-hook 'pm-debug-highlight-current-span))
    (delete-overlay pm--underline-overlay)
    (delete-overlay pm--highlight-overlay)
    (remove-hook 'post-command-hook 'pm-debug-highlight-current-span)))

(defun pm-debug-minor-mode-on ()
  ;; activating everywhere (in case font-lock infloops in a polymode buffer )
  ;; this doesn't activate in fundamental mode
  (unless (eq major-mode 'minibuffer-inactive-mode)
    (pm-debug-minor-mode t)))

(define-globalized-minor-mode pm-debug-mode pm-debug-minor-mode pm-debug-minor-mode-on)


;;; INFO

(cl-defgeneric pm-debug-info (chunkmode))
(cl-defmethod pm-debug-info (chunkmode)
  (eieio-object-name chunkmode))
(cl-defmethod pm-debug-info ((chunkmode pm-inner-chunkmode))
  (format "%s head-matcher:\"%s\" tail-matcher:\"%s\""
          (cl-call-next-method)
          (eieio-oref chunkmode 'head-matcher)
          (eieio-oref chunkmode 'tail-matcher)))
(cl-defmethod pm-debug-info ((_chunkmode pm-inner-auto-chunkmode))
  (cl-call-next-method))

(defvar syntax-ppss-wide)
(defvar syntax-ppss-last)
(defun pm--debug-info (&optional span as-list)
  (let* ((span (or span (and polymode-mode (pm-innermost-span))))
         (message-log-max nil)
         (beg (nth 1 span))
         (end (nth 2 span))
         (obj (nth 3 span))
         (type (and span (or (car span) 'host))))
    (let ((out (list (current-buffer)
                     (point-min) (point) (point-max)
                     major-mode
                     type beg end
                     (and obj (pm-debug-info obj))
                     (format "lppss:%s"
                             (if pm--emacs>26
                                 (car syntax-ppss-wide)
                               syntax-ppss-last)))))
      (if as-list
          out
        (apply #'format
               "(%s) min:%d pos:%d max:%d || (%s) type:%s span:%s-%s %s %s"
               out)))))

(defun pm-debug-info-on-current-span (no-cache)
  "Show info on current span.
With NO-CACHE prefix, don't use cached values of the span."
  (interactive "P")
  (if (not polymode-mode)
      (message "not in a polymode buffer")
    (let ((span (pm-innermost-span nil no-cache)))
      (message (pm--debug-info span))
      ;; (move-overlay pm--highlight-overlay (nth 1 span) (nth 2 span) (current-buffer))
      (pm-debug-flick-region (nth 1 span) (nth 2 span)))))


;;; TOGGLING

(defvar pm-debug-display-info-message nil)
(defun pm-debug-toogle-info-message ()
  "Toggle permanent info display."
  (interactive)
  (setq pm-debug-display-info-message (not pm-debug-display-info-message)))

(defvar poly-lock-allow-fontification)
(defun pm-debug-toggle-fontification ()
  "Enable or disable fontification in polymode buffers."
  (interactive)
  (if poly-lock-allow-fontification
      (progn
        (message "fontificaiton disabled")
        (setq poly-lock-allow-fontification nil
              font-lock-mode nil))
    (message "fontificaiton enabled")
    (setq poly-lock-allow-fontification t
          font-lock-mode t)))

(defun pm-debug-toggle-verbose-syntax ()
  "Toggle syntax related polymode messages."
  (interactive)
  (setq pm-syntax-verbose (not pm-syntax-verbose))
  (if pm-syntax-verbose
      (message "verbose syntax enabled")
    (message "verbose syntax disabled")))

(defun pm-debug-toggle-verbose ()
  "Activate verbose tracing for polymode core functions."
  (interactive)
  (if (or poly-lock-verbose pm-verbose)
      (progn
        (message "verbose log disabled")
        (setq poly-lock-verbose nil
              pm-verbose nil))
    (message "verbose log enabled")
    (setq poly-lock-verbose t
          pm-verbose t)))

(defun pm-debug-toggle-after-change ()
  "Allow or disallow polymode actions in `after-change-functions'."
  (interactive)
  (if pm-allow-after-change-hook
      (progn
        (message "after-change disabled")
        (setq pm-allow-after-change-hook nil))
    (message "after-change enabled")
    (setq pm-allow-after-change-hook t)))

(defun pm-debug-toggle-post-command ()
  "Allow or disallow polymode actions in `post-command-hook'."
  (interactive)
  (if pm-allow-post-command-hook
      (progn
        (message "post-command disabled")
        (setq pm-allow-post-command-hook nil))
    (message "post-command enabled")
    (setq pm-allow-post-command-hook t)))

(defun pm-debug-toggle-all ()
  "Toggle all polymode guards back and forth."
  (interactive)
  (if poly-lock-allow-fontification
      (progn
        (message "fontificaiton, after-chnage and command-hook disabled")
        (setq poly-lock-allow-fontification nil
              pm-allow-after-change-hook nil
              pm-allow-post-command-hook nil))
    (message "fontificaiton, after-change and command-hook enabled")
    (setq poly-lock-allow-fontification t
          pm-allow-after-change-hook t
          pm-allow-post-command-hook t)))


;;; FONT-LOCK

(defun pm-debug-fontify-current-span ()
  "Fontify current span."
  (interactive)
  (let ((span (pm-innermost-span))
        (poly-lock-allow-fontification t))
    (poly-lock-flush (nth 1 span) (nth 2 span))
    (poly-lock-fontify-now (nth 1 span) (nth 2 span))))

(defun pm-debug-fontify-current-buffer ()
  "Fontify current buffer."
  (interactive)
  (let ((poly-lock-allow-fontification t))
    (poly-lock-flush (point-min) (point-max))
    (poly-lock-fontify-now (point-min) (point-max))))


;;; TRACING

(defun pm-debug-trace-background-1 (fn)
  "Trace FN in background."
  (unless (symbolp fn)
    (error "Can trace symbols only"))
  (unless (get fn 'cl--class)
    (trace-function-background fn nil
                               '(lambda ()
                                  (format " [buf:%s pos:%s type:%s (%f)]"
                                          (current-buffer) (point)
                                          (car (get-text-property (point) :pm-span))
                                          (float-time))))))

(defun pm-debug-trace-functions-by-regexp (regexp)
  "Trace all functions whose name matched REGEXP."
  (interactive "sRegex: ")
  (cl-loop for sym being the symbols
           when (and (fboundp sym)
                     (not (eq sym 'pm-debug-trace-background-1)))
           when (string-match regexp (symbol-name sym))
           do (pm-debug-trace-background-1 sym)))

(declare-function untrace-all "trace")
(defmacro pm-debug-eval-with-trace (regexp &rest body)
  "Trace all functions matched with REGEXP during the execution of BODY."
  (declare (indent 1) (debug (sexp body)))
  `(let ((trace-buf- (get-buffer-create "*trace-output*")))
     (unwind-protect
         (progn
           (with-current-buffer trace-buf-
             (erase-buffer))
           (pm-debug-trace-functions-by-regexp ,regexp)
           ,@body
           ;; ensure jit-lock finished
           (sit-for 1)
           (pop-to-buffer trace-buf-)
           (goto-char (point-min)))
       (untrace-all))))

(defun pm-debug-fontify-with-trace (span-only)
  "Trace fontification functions during the fontification of the current buffer.
On SPAN-ONLY prefix, fontify current span only."
  (interactive "P")
  (let ((reg (if span-only
                 (let ((span (pm-innermost-span)))
                   (cons (nth 1 span) (nth 2 span)))
               (cons (point-min) (point-max)))))
    (pm-debug-eval-with-trace "\\(jit\\|poly\\|font\\)-lock-"
      (font-lock-flush (car reg) (cdr reg))
      (font-lock-unfontify-region (car reg) (cdr reg))
      (font-lock-ensure (car reg) (cdr reg)))))

(defun pm-debug-visit-file-with-trace (file)
  "Trace fontification functions during the fontification of FILE."
  (interactive "f")
  (pm-debug-eval-with-trace "\\(jit\\|poly\\|font\\)-lock-"
    (find-file-noselect file)))


;;; RELEVANT VARIABLES

(defvar pm-debug-relevant-variables
  '(after-save-hook
    before-save-hook
    revert-buffer-function
    before-revert-hook
    after-revert-hook
    fontification-functions
    font-lock-function
    font-lock-flush-function
    font-lock-ensure-function
    font-lock-fontify-region-function
    font-lock-fontify-buffer-function
    font-lock-unfontify-region-function
    font-lock-unfontify-buffer-function
    jit-lock-after-change-extend-region-functions
    jit-lock-functions
    syntax-propertize-function
    syntax-propertize-extend-region-functions
    pm--syntax-propertize-function-original
    pm--indent-line-function-original
    pre-command-hook
    post-command-hook
    before-change-functions
    after-change-functions
    indent-line-function))

(defun pm-debug-print-relevant-variables ()
  "Print values of relevant hooks and other variables."
  (interactive)
  (let ((buff (get-buffer-create "*polymode-vars*"))
        (vars (mapcar (lambda (v) (cons v (buffer-local-value v (current-buffer))))
                      pm-debug-relevant-variables))
        (cbuff (current-buffer)))
    (require 'pp)
    (with-current-buffer buff
      (goto-char (point-max))
      (insert "===============================================================\n")
      (insert (format "relevant vars in buffer: %s\n" cbuff))
      (insert (pp-to-string vars))
      (toggle-truncate-lines -1))
    (display-buffer buff)))


;;; HIGHLIGHT

(defun pm-debug-highlight-current-span ()
  (when polymode-mode
    (unless (memq this-command '(pm-debug-info-on-current-span
                                 pm-debug-highlight-last-font-lock-error-region))
      (delete-overlay pm--highlight-overlay))
    (condition-case err
        (let ((span (pm-innermost-span)))
          (when pm-debug-display-info-message
            (message (pm--debug-info span)))
          (move-overlay pm--underline-overlay (nth 1 span) (nth 2 span) (current-buffer)))
      (error (message "%s" (error-message-string err))))))

(defun pm-debug-flick-region (start end &optional delay)
  (move-overlay pm--highlight-overlay start end (current-buffer))
  (run-with-timer (or delay 0.4) nil (lambda () (delete-overlay pm--highlight-overlay))))

(defun pm-debug-map-over-spans-and-highlight ()
  "Map over all spans in the buffer and highlight briefly."
  (interactive)
  (pm-map-over-spans (lambda ()
                       (let ((start (nth 1 *span*))
                             (end (nth 2 *span*)))
                         (pm-debug-flick-region start end)
                         (sit-for 1)))
                     (point-min) (point-max) nil nil t))

(defun pm-debug-run-over-check (no-cache)
  "Map over all spans and report the time taken.
Switch to buffer is performed on every position in the buffer.
On prefix NO-CACHE don't use cached spans."
  (interactive)
  (goto-char (point-min))
  (let ((start (current-time))
        (count 1)
        (pm-initialization-in-progress no-cache))
    (pm-switch-to-buffer)
    (while (< (point) (point-max))
      (setq count (1+ count))
      (forward-char)
      (pm-switch-to-buffer))
    (let ((elapsed  (float-time (time-subtract (current-time) start))))
      (message "Elapsed: %s  per-char: %s" elapsed (/ elapsed count)))))

(defun pm-dbg (msg &rest args)
  (let ((cbuf (current-buffer))
        (cpos (point)))
    (with-current-buffer (get-buffer-create "*pm-dbg*")
      (save-excursion
        (goto-char (point-max))
        (insert "\n")
        (insert (apply 'format (concat "%f [%s at %d]: " msg)
                       (float-time) cbuf cpos args))))))

(provide 'polymode-debug)
;;; polymode-debug.el ends here