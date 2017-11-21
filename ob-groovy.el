;;; ob-groovy.el --- org-babel functions for groovy evaluation

;; Copyright (C) 2017 Feng Zhou

;; Author: Feng Zhou <zf.pascal@gmail.com>
;; URL: http://github.com/zweifisch/ob-groovy
;; Keywords: org babel groovy
;; Version: 0.0.1
;; Created: 11th Nov 2017
;; Package-Requires: ((org "8"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; org-babel functions for groovy evaluation
;;

;;; Code:
(require 'ob)

(defvar ob-groovy-process-output "")

(defvar ob-groovy-eoe "ob-groovy-eoe")

(defun org-babel-execute:groovy (body params)
  (let ((session (cdr (assoc :session params))))
    (if (string= "none" session)
        (ob-groovy--eval body)
      (ob-groovy--ensure-session session)
      (ob-groovy--eval-in-repl session body))))

(defun ob-groovy--eval (body)
  (let ((tmp (format "%s.groovy" (org-babel-temp-file "Groovy"))))
    (with-temp-file tmp
      (insert body))
    (shell-command-to-string (format "groovy %s" tmp))))

(defun ob-groovy--ensure-session (session)
  (let ((name (format "*ob-groovy-%s*" session)))
    (unless (and (get-process name)
                 (process-live-p (get-process name)))
      (let ((process (with-current-buffer (get-buffer-create name)
                       (start-process name name "groovysh" "--color=false"))))
        (set-process-filter process 'ob-groovy--process-filter)
        (ob-groovy--wait "groovy:000>")))))

(defun ob-groovy--process-filter (process output)
  (with-current-buffer (process-buffer process)
    (goto-char (point-max))
    (insert output))
  (setq ob-groovy-process-output (concat ob-groovy-process-output output)))

(defun ob-groovy--wait (pattern)
  (while (not (string-match-p pattern ob-groovy-process-output))
    (sit-for 0.5)))

(defun ob-groovy--last-match (pattern string) 
  (let ((start 0)
        (len 0))
    (while (string-match pattern string start)
      (setq start (+ start 1)
            len (length (match-string 0 string))))
    (cons (- start 1) len)))

(defun ob-groovy--find-last-output (output)
  (let ((match (ob-groovy--last-match "===> " output)))
    (substring-no-properties output (+ (car match) (cdr match)))))

(defun ob-groovy--eval-in-repl (session body)
  (let ((name (format "*ob-groovy-%s*" session)))
    (setq ob-groovy-process-output "")
    (process-send-string name (format "%s\n\"%s\"\n" body ob-groovy-eoe))
    (accept-process-output (get-process name) nil nil 1)
    (ob-groovy--wait ob-groovy-eoe)
    (ob-groovy--find-last-output
     (replace-regexp-in-string
      (format "===> %s\n" ob-groovy-eoe) ""
      (replace-regexp-in-string
       "groovy:[0-9]+> " "" ob-groovy-process-output)))))

(provide 'ob-groovy)
;;; ob-groovy.el ends here
