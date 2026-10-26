;;; sz-neotree.el --- Project file sidebar (neotree) -*- lexical-binding: t; -*-
;;; Commentary:
;; Doom-style sidebar: single-letter file operations in the tree.  Reached from
;; the leader as SPC p o / SPC p O (sz-keys.el).  neotree-mode runs in meow
;; MOTION state, so meow owns j/k and SPC and every other key is neotree's.
;;
;; Helpers are defined above the `use-package' form: `:bind' emits an
;; `fboundp'-guarded autoload for every bound symbol, and defining them first
;; keeps it from stubbing the sz/ commands as autoloads of neotree.
;;; Code:

(defun sz/neotree/set-theme (&rest _)
  "Set `neo-theme' from the selected frame's display capabilities."
  (setq neo-theme (if (display-graphic-p) 'nerd-icons 'arrow)))

(if (daemonp)
    (add-hook 'server-after-make-frame-hook #'sz/neotree/set-theme)
  (add-hook 'elpaca-after-init-hook #'sz/neotree/set-theme))

(defun sz/neotree/project-root ()
  "Project root of the current buffer, or `default-directory'."
  (or (when-let* ((proj (project-current))) (project-root proj))
      default-directory))

(defun sz/neotree/open ()
  "Open neotree at the project root and reveal the current file."
  (interactive)
  (let ((file buffer-file-name)
        (root (sz/neotree/project-root)))
    (neotree-dir root)
    (when file (neotree-find file))))

(defun sz/neotree/toggle ()
  "Toggle a project-rooted neotree sidebar, revealing the current file."
  (interactive)
  (if (neo-global--window-exists-p)
      (neotree-hide)
    (sz/neotree/open)))

(defun sz/neotree/expand-or-open ()
  "Expand the directory at point, descend into it, or open the file at point."
  (interactive)
  (let ((node (neo-buffer--get-filename-current-line)))
    (cond
     ((or (null node) (not (file-directory-p node)))
      (call-interactively #'neotree-enter))
     ((neo-buffer--expanded-node-p node)
      (forward-line 1))
     (t
      (neo-buffer--set-expand node t)
      (neo-buffer--refresh t)))))

(defun sz/neotree/collapse-or-up ()
  "Collapse the expanded directory at point, else select its parent node."
  (interactive)
  (let ((node (neo-buffer--get-filename-current-line)))
    (if (and node
             (file-directory-p node)
             (neo-buffer--expanded-node-p node))
        (progn
          (neo-buffer--set-expand node nil)
          (neo-buffer--refresh t))
      (neotree-select-up-node))))

(defun sz/neotree/dired ()
  "Open the node at point in `dired'."
  (interactive)
  (when-let* ((node (neo-buffer--get-filename-current-line)))
    (dired (if (file-directory-p node) node (file-name-directory node)))))

(use-package neotree
  :ensure t
  :after nerd-icons
  :commands (neotree-toggle neotree-dir neotree-find neotree-hide
             neo-global--window-exists-p)
  :bind ( :map neotree-mode-map
          ("h" . sz/neotree/collapse-or-up)
          ("l" . sz/neotree/expand-or-open)
          ("J" . neotree-select-next-sibling-node)
          ("K" . neotree-select-previous-sibling-node)
          ("L" . neotree-select-down-node)
          ("c" . neotree-create-node)
          ("d" . neotree-delete-node)
          ("r" . neotree-rename-node)
          ("y" . neotree-copy-filepath-to-yank-ring)
          ("Y" . neotree-copy-node)
          ("R" . neotree-change-root)
          ("C" . neotree-collapse-all)
          ("v" . neotree-enter-vertical-split)
          ("s" . neotree-enter-horizontal-split)
          ("z" . neotree-stretch-toggle)
          ("D" . sz/neotree/dired))
  :init
  (setq neo-theme 'nerd-icons
        neo-smart-open t            ; jump to current file when opening
        neo-window-width 30
        neo-window-fixed-size nil   ; keep manual resize
        neo-show-updir-line nil
        neo-mode-line-type 'none
        neo-banner-message nil
        neo-autorefresh nil
        neo-show-hidden-files nil
        neo-hide-cursor t           ; also turns on hl-line in the sidebar
        neo-create-file-auto-open nil
        neo-confirm-create-file #'off-p
        neo-confirm-create-directory #'off-p
        neo-hidden-regexp-list
        '("^\\."                     ; dotfiles/dirs (.git, .direnv, ...)
          "~$" "^#.*#$"              ; backups / autosaves
          "\\.\\(pyc\\|elc\\|o\\|class\\)$"
          "^\\(node_modules\\|vendor\\)$"))
  :config
  ;; meow MOTION keeps neotree's own keymap live while meow owns j/k and SPC.
  (with-eval-after-load 'meow
    (add-to-list 'meow-mode-state-list '(neotree-mode . motion))))

(provide 'sz-neotree)
;;; sz-neotree.el ends here
