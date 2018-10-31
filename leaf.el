;;; leaf.el ---                                      -*- lexical-binding: t; -*-

;; Copyright (C) 2018  Naoya Yamashita

;; Author: Naoya Yamashita
;; Keywords: settings

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

;;; Code:

(defcustom leaf-keywords
  '(:disabled
    :if :when :unless
    ;; Any other keyword that also declares commands to be autoloaded
    ;; (such as :bind) must appear before this keyword.
    :init
    ;; This must occur almost last; the only forms which should appear after
    ;; are those that must happen directly after the config forms.
    :config)
  "leaf-keywords")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  support functions
;;

(defun leaf-merge-dupkey-values-plist (plist)
  "Given a PLIST, merge duplicate key values.

EXAMPLE:
(leaf-merge-value-on-duplicate-key
  '(:defer (t)
    :config ((message \"a\") (message \"b\"))
    :config ((message \"c\"))))
 -> (:defer (t)
     :config ((message \"a\") (message \"b\") (message \"c\")))"
  (let ((retplist) (existkeys) (existvalue) (key) (value))
    (while plist
      (setq key (pop plist))
      (setq value (pop plist))

      (if (plist-member retplist key)
	  (plist-put retplist key `(,@(plist-get retplist key) ,@value))
	(setq retplist `(,@retplist ,key ,value))))
    retplist))

(defun leaf-normalize-plist (plist mergep)
  "Given a pseudo-PLIST, normalize it to a regular plist.
if MERGEP is t, merge duplicate key values.

EXAMPLE:
(leaf-normalize-plist
  '(:defer t
    :config (message \"a\") (message \"b\")
    :config (message \"c\")) nil)
 -> (:defer (t)
     :config ((message \"a\") (message \"b\"))
     :config ((message \"c\")))

(leaf-normalize-plist
  '(:defer t
    :config (message \"a\") (message \"b\")
    :config (message \"c\")) t)
 -> (:defer (t)
     :config ((message \"a\") (message \"b\") (message \"c\"))"

  ;; using reverse list, push (:keyword worklist) when find :keyword
  (let ((retplist) (worklist) (rlist (reverse plist)))
    (dolist (target rlist)
      (if (keywordp target)
	  (progn
	    (push worklist retplist)
	    (push target retplist)

	    ;; clean worklist for new keyword
	    (setq worklist nil))
	(push target worklist)))
    
    ;; merge value for duplicated key if MERGEP is t
    (if mergep (leaf-merge-dupkey-values-plist retplist) retplist)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  keyword handlers
;;

(defun leaf-process-keywords (name plist)
  "Process keywords for NAME.

NOTE:
Not check PLIST, PLIST has already been carefully checked 
parent funcitons.
Don't call this function directory."

  (when plist
    (let* ((key         (pop plist))
	   (value       (pop plist))
	   (rest        plist)
	   (handler     (format "leaf-handler/%s" key))
	   (handler-sym (intern handler)))
      (funcall handler-sym name value rest))))

(defun leaf-handler/:disabled (name value rest)
  "Process :disabled.

This handler always return nil, and interrupt processing of
remaining arguments"
  nil)

(defun leaf-handler/:if (name value rest)
  "Process :if.

This handler surround the processing of the remaining arguments
with an if block"
  (let ((body (leaf-process-keywords name rest)))
    `(if ,value ,body)))

(defun leaf-handler/:when (name value rest)
  "Process :when.

This handler surround the processing of the remaining arguments
with an when block"
  (let ((body (leaf-process-keywords name rest)))
    `(when ,value ,body)))

(defun leaf-handler/:unless (name value rest)
  "Process :unless.

This handler surround the processing of the remaining arguments
with an unless block"
  (let ((body (leaf-process-keywords name rest)))
    `(unless ,value ,body)))

(defun leaf-handler/:config (name value rest)
  "Process :config.

This handler return value with progn form."
  (let ((body (leaf-process-keywords name rest)))
    `(progn ,value)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  main macros
;;

(defmacro leaf-core (name args)
  (let ((args* (leaf-normalize-plist args t)))
    (leaf-process-keywords name args*)))

(defmacro leaf (name &rest args)
  (declare (indent 1))
  "leaf macro"
  `(leaf-core ,name ,args))

(provide 'leaf)
;;; leaf.el ends here
