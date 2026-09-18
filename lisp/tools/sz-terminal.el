;;; sz-terminal.el --- In-Emacs terminal -*- lexical-binding: t; -*-
;;; Commentary:
;; eat ("Emulate A Terminal") -- a fast, pure-elisp terminal that runs a real
;; shell inside a buffer (no external deps, unlike vterm).  Bindings live in
;; sz-keys (SPC p e / SPC p t -> `eat-project-other-window'); `M-x eat' opens a
;; terminal in the current `default-directory'.
;;; Code:

(use-package eat
  :ensure t
  :commands (eat eat-project eat-project-other-window)
  :custom
  ;; Close the buffer when the shell exits, like a real terminal window.
  (eat-kill-buffer-on-exit t)
  :config
  ;; Run eshell's visual commands (top, htop, ...) inside an eat terminal.
  (add-hook 'eshell-load-hook #'eat-eshell-mode))

(provide 'sz-terminal)
;;; sz-terminal.el ends here
