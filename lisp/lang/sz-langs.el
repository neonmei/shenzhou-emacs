;;; sz-langs.el --- Languages: tree-sitter, flymake, major modes -*- lexical-binding: t; -*-
;;; Commentary:
;; Tree-sitter, flymake, and the small language/format modes that need no
;; extra configuration beyond their file association.  LSP lives in
;; sz-eglot.el; languages with real tooling get their own file in lisp/lang/.
;; External tools (grammars, language servers) are declared in Nix; everything
;; here degrades gracefully when a grammar/server is absent.
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
(use-package yaml-mode       :ensure t :mode "\\.ya?ml\\'")
(use-package dockerfile-mode :ensure t)

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

;;;; --- Flymake (diagnostics) ---------------------------------------------------

(use-package flymake
  :ensure nil
  :hook (prog-mode . flymake-mode)
  :bind (:map flymake-mode-map
              ("M-n" . flymake-goto-next-error)
              ("M-p" . flymake-goto-prev-error)
              ("C-c ! l" . flymake-show-buffer-diagnostics)))

(provide 'sz-langs)
;;; sz-langs.el ends here
