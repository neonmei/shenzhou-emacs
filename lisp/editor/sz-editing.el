;;; sz-editing.el --- Modal editing with meow -*- lexical-binding: t; -*-
;;; Commentary:
;; General editing. Zen / distraction-free writing and vundo.
;;; Code:

;;;; --- Persistence (built-ins) -------------------------------------------------

(use-package recentf
  :ensure nil
  :demand t
  :init (setq recentf-save-file (sz/var "recentf")
              recentf-max-saved-items 300)
  :config (recentf-mode 1))

(use-package savehist
  :ensure nil
  :demand t
  :init (setq savehist-file (sz/var "savehist"))
  :config (savehist-mode 1))

(use-package saveplace
  :ensure nil
  :demand t
  :init (setq save-place-file (sz/var "saveplace"))
  :config (save-place-mode 1))

;; which-key is built-in on Emacs 30.1+, so do not :ensure it.
(use-package which-key
  :ensure nil
  :config (which-key-mode 1))

(use-package writeroom-mode
  :ensure t
  :commands (writeroom-mode global-writeroom-mode)
  :custom
  (writeroom-width 100)
  (writeroom-mode-line t)                 ; keep the modeline visible
  (writeroom-global-effects               ; don't fullscreen the frame
   '(writeroom-set-alpha
     writeroom-set-menu-bar-lines writeroom-set-tool-bar-lines
     writeroom-set-vertical-scroll-bars writeroom-set-bottom-divider-width)))

;; Visual undo tree (replaces the bare `undo' on C-x u; meow `u'/`U' still undo).
(use-package vundo
  :ensure t
  :bind ("C-x u" . vundo)
  :custom (vundo-compact-display t)
  :config (setq vundo-glyph-alist vundo-unicode-symbols))

;; Marginal annotations saved in a separate DB, without modifying the file.
;; Enable per-buffer with `annotate-mode' (default prefix C-c C-a).
(use-package annotate
  :ensure t
  :commands (annotate-mode)
  :init (setq annotate-file (sz/var "annotations")))

(use-package whole-line-or-region
  :ensure t
  :config (whole-line-or-region-global-mode 1)
  )

;; magnars multiple-cursors; leader bindings live in sz-keys.el (SPC m / C-c m).
(use-package multiple-cursors
  :ensure t
  :init (setq mc/list-file (sz/var "mc-lists.el"))
  :bind (("C->"     . mc/mark-next-like-this)
         ("C-<"     . mc/mark-previous-like-this)
         ("C-c C-<" . mc/mark-all-like-this)))

;; Window navigation: C-M-<arrow> moves between windows.
(windmove-default-keybindings '(control meta))
(global-auto-revert-mode 1)
(setq tab-width 2)

(setopt auto-revert-avoid-polling t)
(setopt auto-revert-interval 5)
(setopt auto-revert-check-vc-info t)
(global-auto-revert-mode)

(setopt show-paren-delay 0)
(setopt show-paren-mode t)
(setopt show-paren-style 'parenthesis)   ; default is 'parenthesis and just does delimiters
(setopt show-paren-context-when-offscreen 'overlay)


;;;; --- Yank file path (SPC f y / SPC f Y) ---------------------------------------

(defun sz/yank-file-path ()
  "Copy the current buffer's absolute file path to the kill ring."
  (interactive)
  (if-let* ((file (buffer-file-name)))
      (progn
        (kill-new file)
        (message "Yanked: %s" file))
    (user-error "Buffer is not visiting a file")))

(defun sz/yank-file-path-relative ()
  "Copy the current buffer's file path, relative to the project root."
  (interactive)
  (if-let* ((file (buffer-file-name)))
      (let ((relative-path (file-relative-name file (project-root (project-current t)))))
        (kill-new relative-path)
        (message "Yanked: %s" relative-path))
    (user-error "Buffer is not visiting a file")))

(provide 'sz-editing)
;;; sz-editing.el ends here
