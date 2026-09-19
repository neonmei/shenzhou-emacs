;;; sz-eglot.el --- LSP: eglot, lsp-booster, eldoc-box -*- lexical-binding: t; -*-
;;; Commentary:
;; The built-in eglot LSP client (+ emacs-lsp-booster), childframe docs via
;; eldoc-box, and server registrations for languages without their own file in
;; lisp/lang/.  Language servers are declared in Nix.
;;; Code:

;; LSP throughput: allow large process reads.
(setq read-process-output-max (* 4 1024 1024))

;;;; --- Eglot (LSP) -------------------------------------------------------------

(declare-function eglot--lookup-mode "eglot")

(defun sz/eglot-ensure-maybe ()
  "Start eglot only if `eglot-server-programs' names a server for this buffer."
  (require 'eglot)
  (when (cdr (eglot--lookup-mode major-mode))
    (eglot-ensure)))

(use-package eglot
  :ensure nil
  :hook (prog-mode . sz/eglot-ensure-maybe)
  :custom
  (eglot-autoshutdown t)
  (eglot-events-buffer-size 0)
  (eglot-extend-to-xref t)
  (eglot-autoshutdown t)
  (eglot-sync-connect nil)
  )

(defvar tramp-methods)
(defvar connection-local-profile-alist)
(defvar connection-local-criteria-alist)

(defun sz/eglot-tramp-direct (connect &rest args)
  "Call CONNECT with ARGS, starting a remote server as a direct pipe process."
  (if (not (file-remote-p default-directory))
      (apply connect args)
    (let ((connection-local-profile-alist
           (cons '(sz-eglot-direct-async (tramp-direct-async-process . t))
                 connection-local-profile-alist))
          (connection-local-criteria-alist
           (cons '((:application tramp) sz-eglot-direct-async)
                 connection-local-criteria-alist))
          (tramp-methods
           (mapcar (lambda (method)
                     (if (let ((direct (cadr (assq 'tramp-direct-async method))))
                           (and (consp direct) (member "-t" direct)))
                         (cons (car method)
                               (cons '(tramp-direct-async t)
                                     (assq-delete-all 'tramp-direct-async
                                                      (copy-sequence (cdr method)))))
                       method))
                   tramp-methods)))
      (apply connect args))))

; FIXME: nixd over TRAMP is pro-BLE-ma-TIC
(with-eval-after-load 'eglot
  (advice-add 'eglot--connect :around #'sz/eglot-tramp-direct))

(defvar sz-beancount-journal-name "main.beancount")

(defun sz-beancount-eglot-options (server)
  "Build beancount-language-server initializationOptions for SERVER."
  (let* ((root (project-root (eglot--project server)))
         (journal (expand-file-name sz-beancount-journal-name root)))
    (list :journal_file journal)))

;; Server tweaks must run AFTER eglot loads (`eglot-server-programs' is defined
;; in eglot.el).  In the use-package `:config' they ran too early -- the
;; resulting void-variable error aborted the form and the `:hook' never applied.
(with-eval-after-load 'eglot
  ;; Servers eglot doesn't know about out of the box (all declared in Nix).
  (add-to-list 'eglot-server-programs '((yaml-mode yaml-ts-mode) . ("yaml-language-server" "--stdio")))
  (add-to-list 'eglot-server-programs
               '(beancount-mode . ("beancount-language-server" "--stdio"
                                   :initializationOptions
                                   sz-beancount-eglot-options)))
  (setq-default eglot-workspace-configuration
                '(:gopls (:usePlaceholders t :staticcheck t :gofumpt t))))

;; LSP performance: route traffic through emacs-lsp-booster (already in Nix).
(use-package eglot-booster
  :ensure (:host github :repo "jdtsmith/eglot-booster")
  :after eglot
  :config
  (when (executable-find "emacs-lsp-booster")
    (eglot-booster-mode)))

;;;; --- eldoc-box (childframe docs) ---------------------------------------------
;; Shows eldoc (eglot signatures/docs) in a GUI childframe at point instead of
;; the one-line echo area.  On demand via `SPC d k' (sz-keys.el).  Childframes
;; need a graphical frame, so this is a no-op in the terminal.

(use-package eldoc-box
  :ensure t)

(provide 'sz-eglot)
;;; sz-eglot.el ends here
