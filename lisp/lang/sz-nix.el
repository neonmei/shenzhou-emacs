;;; sz-nix.el --- Nix: nix-mode, nixd -*- lexical-binding: t; -*-
;;; Commentary:
;; nix-mode owns the file association, nix-ts-mode is the tree-sitter remap
;; target, and nixd is registered as the eglot server.
;;; Code:

(use-package nix-mode        :ensure t :mode "\\.nix\\'")
(use-package nix-ts-mode     :ensure t)   ; remap target for nix

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs '((nix-mode nix-ts-mode) . ("nixd"))))

(provide 'sz-nix)
;;; sz-nix.el ends here
