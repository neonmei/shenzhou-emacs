;;; sz-r.el --- R: ESS (Emacs Speaks Statistics) -*- lexical-binding: t; -*-
;;; Commentary:
;; ESS owns R editing (`ess-r-mode') and the inferior R process; eglot's
;; built-in server registration drives the R `languageserver' package for LSP.
;; Diagnostics come from that server via flymake, so ESS's own flymake backend
;; is off to avoid double-linting.
;;; Code:

(use-package ess
  :ensure t
  :mode ("\\.[rR]\\'" . ess-r-mode)
  :custom
  (ess-ask-for-ess-directory nil)
  (ess-use-flymake nil))

(provide 'sz-r)
;;; sz-r.el ends here
