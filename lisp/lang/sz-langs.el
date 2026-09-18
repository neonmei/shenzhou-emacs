;;; sz-langs.el --- Languages: tree-sitter, eglot, flymake, major modes -*- lexical-binding: t; -*-
;;; Commentary:
;; Tree-sitter, the built-in eglot LSP client (+ lsp-booster), flymake, and
;; the small language/format modes that need no extra configuration beyond
;; their file association.  Languages with real tooling get their own file
;; in lisp/lang/.  External tools (grammars, language servers) are declared in
;; Nix; everything here degrades gracefully when a grammar/server is absent.
;;; Code:

;;;; --- Tree-sitter -------------------------------------------------------------

;(use-package prism :repo "alphapapa/prism.el")

(use-package treesit
  :ensure nil
  :custom
  (treesit-auto-install-grammar 'always) ; EMACS-31
  (treesit-enabled-modes t)              ; EMACS-31
  (treesit-extra-load-path (list (expand-file-name "tree-sitter/" sz-var-dir)))
  (treesit-font-lock-level 4)
  )

;; Classic major-mode packages: they own the file associations and work without
;; a grammar; the remaps above upgrade them to *-ts-mode when the grammar exists.
(use-package rust-mode       :ensure t :mode "\\.rs\\'")
(use-package yaml-mode       :ensure t :mode "\\.ya?ml\\'")
(use-package dockerfile-mode :ensure t)
(use-package nix-mode        :ensure t :mode "\\.nix\\'")
(use-package nix-ts-mode     :ensure t)   ; remap target for nix


(use-package mermaid-mode :ensure t :mode "\\.mmd\\'")
(use-package just-mode :ensure t)
(use-package ssh-config-mode :ensure t)
(use-package beancount :ensure t :mode ("\\.beancount\\'" . beancount-mode))
(use-package ledger-mode :ensure t :mode "\\.ledger\\'")
(use-package markdown-mode :ensure t :mode ("\\.md\\'" . gfm-mode))

(use-package jinja2-mode :ensure t :mode ("\\.j2\\'" "\\.jinja2?\\'"))
(use-package ansible :ensure t :hook ((yaml-mode yaml-ts-mode) . ansible))
(use-package ansible-doc :ensure t :hook (ansible . ansible-doc-mode))

(use-package protobuf-mode
  :ensure (:host github :repo "emacsmirror/protobuf-mode"
           :files ("protobuf-mode.el"))
  :mode "\\.proto\\'")

(use-package hurl-mode
  :ensure (:host github :repo "Orange-OpenSource/hurl"
           :files ("contrib/emacs/*.el"))
  :mode "\\.hurl\\'")

(use-package markdown-ts-mode
  :ensure nil
  :defer t)

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
  (add-to-list 'eglot-server-programs '((nix-mode nix-ts-mode) . ("nixd")))
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

;;;; --- Flymake (diagnostics) ---------------------------------------------------

(use-package flymake
  :ensure nil
  :hook (prog-mode . flymake-mode)
  :bind (:map flymake-mode-map
              ("M-n" . flymake-goto-next-error)
              ("M-p" . flymake-goto-prev-error)
              ("C-c ! l" . flymake-show-buffer-diagnostics)))

;;;; --- Python ------------------------------------------------------------------
(use-package pet
  :ensure t
  :config
  (add-hook 'python-base-mode-hook #'pet-mode -10))

(provide 'sz-langs)
;;; sz-langs.el ends here
