;;; sz-rust.el --- Rust: rust-mode -*- lexical-binding: t; -*-
;;; Commentary:
;; rust-mode owns the file association; eglot's built-in default server
;; (rust-analyzer) handles LSP.
;;; Code:

(use-package rust-mode       :ensure t :mode "\\.rs\\'")

(provide 'sz-rust)
;;; sz-rust.el ends here
