;;; sz-workspace.el --- Workspaces (perspective) and file tree (neotree) -*- lexical-binding: t; -*-
;;; Commentary:
;; Ports Doom's `SPC TAB' workspace leader onto `perspective'.  Each perspective
;; is a named workspace with its own buffer list and window configuration.  The
;; prefix `sz-workspace-map' is attached to SPC TAB in sz-meow.el and to
;; C-c TAB in sz-keys.el.
;;
;; Defined at top level (not inside the deferred `use-package') so the keymap
;; object exists as soon as this module is required -- sz-keys.el references it
;; as a value for the C-c TAB binding.  Leaves hold command symbols resolved at
;; key-press time, so binding them before perspective finishes building is safe.
;;
;; Neotree provides the project-rooted file sidebar (SPC p o / SPC p O).
;;; Code:

(defvar sz-var-dir)

(define-prefix-command 'sz-workspace-map)

;;;; --- Package ---------------------------------------------------------------------

(use-package perspective
  :ensure t
  :init
  (setq persp-suppress-no-prefix-key-warning t
        persp-state-default-file (expand-file-name "perspectives.el" sz-var-dir)
        persp-modestring-short t
        )
  :config
  (persp-mode 1)
  (with-eval-after-load 'consult
    (consult-customize consult-source-buffer :hidden t :default nil)
    (add-to-list 'consult-buffer-sources persp-consult-source)))

;;;; --- Helpers ------------------------------------------------------------------

(defun sz/workspace/display ()
  "Show all perspectives in the echo area, highlighting the current one."
  (interactive)
  (message "%s"
           (mapconcat (lambda (name)
                        (if (equal name (persp-current-name))
                            (propertize (format "[%s]" name) 'face 'warning)
                          name))
                      (persp-names)
                      "  ")))

(defun sz/workspace/new ()
  "Create and switch to a new auto-named perspective showing the dashboard."
  (interactive)
  (persp-switch (format "Workspace #%d" (1+ (length (persp-names)))))
  (dashboard-open)
  (delete-other-windows))

(defun sz/workspace/new-named (name)
  "Create and switch to a new perspective called NAME, showing the dashboard."
  (interactive (list (read-string "New workspace name: ")))
  (unless (persp-valid-name-p name)
    (user-error "Workspace name must not be empty"))
  (when (member name (persp-names))
    (user-error "Workspace `%s' already exists" name))
  (persp-switch name)
  (dashboard-open)
  (delete-other-windows))



;;;; --- Workspace lifecycle -------------------------------------------------------

(define-key sz-workspace-map (kbd "TAB") #'persp-switch)
(define-key sz-workspace-map "."  #'persp-switch)
(define-key sz-workspace-map "`"  #'persp-switch-last)
(define-key sz-workspace-map "n"  #'sz/workspace/new)
(define-key sz-workspace-map "N"  #'sz/workspace/new-named)
(define-key sz-workspace-map "r"  #'persp-rename)
(define-key sz-workspace-map "d"  #'persp-kill)
(define-key sz-workspace-map "k"  #'persp-kill)
(define-key sz-workspace-map "s"  #'persp-state-save)
(define-key sz-workspace-map "l"  #'persp-state-load)
(define-key sz-workspace-map "b"  #'persp-switch-to-buffer*)

;;;; --- Navigation -----------------------------------------------------------------

(define-key sz-workspace-map "]"  #'persp-next)
(define-key sz-workspace-map "["  #'persp-prev)
(dotimes (i 9)
  (let ((n (1+ i)))
    (define-key sz-workspace-map (number-to-string n)
      (lambda () (interactive) (persp-switch-by-number n)))))


(defun sz/persp/make-tab-format ()
  "Render perspectives as tab-bar items."
  (let ((current (persp-current-name)))
    (mapcar
     (lambda (name)
       `(,(intern (format "persp-%s" name))
         menu-item
         ,(propertize (format " %s " name)
                      'face (if (equal name current)
                                'tab-bar-tab
                              'tab-bar-tab-inactive))
         ,(lambda () (interactive) (persp-switch name))
         :help ,(format "Switch to perspective %s" name)))
     (persp-names))))

(setq tab-bar-format '(sz/persp/make-tab-format
                       tab-bar-format-align-right
                       tab-bar-format-global))

(tab-bar-mode 1)

;;;; --- Neotree -----------------------------------------------------------------
(use-package neotree
  :ensure t
  :after nerd-icons
  :commands (neotree-toggle neotree-dir neotree-find neotree-hide
             neo-global--window-exists-p)
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
        neo-confirm-create-file (lambda (&rest _) t)
        neo-confirm-create-directory (lambda (&rest _) t)
        neo-hidden-regexp-list
        '("^\\."                     ; dotfiles/dirs (.git, .direnv, ...)
          "~$" "^#.*#$"              ; backups / autosaves
          "\\.\\(pyc\\|elc\\|o\\|class\\)$"
          "^\\(node_modules\\|vendor\\)$"))
  :config
  ;; Doom-style visual polish in the neo window: highlight the current line,
  ;; hide the block cursor.
  (add-hook 'neo-after-create-hook
            (lambda (&rest _)
              (hl-line-mode 1)
              (setq-local cursor-type nil)))

  ;; Under meow, run the neotree buffer in motion state so its own keymap
  ;; (RET/TAB open, q hide, H toggle hidden, g refresh) stays live while
  ;; meow-motion's j/k move the tree and SPC remains the leader.
  (with-eval-after-load 'meow
    (add-to-list 'meow-mode-state-list '(neotree-mode . motion))))

(defun sz/neotree-set-theme (&rest _)
  "Set `neo-theme' from the selected frame's display capabilities."
  (setq neo-theme (if (display-graphic-p) 'nerd-icons 'arrow)))

(if (daemonp)
    (add-hook 'server-after-make-frame-hook #'sz/neotree-set-theme)
  (add-hook 'elpaca-after-init-hook #'sz/neotree-set-theme))

(defun sz/neotree-project-root ()
  "Project root of the current buffer, or `default-directory'."
  (or (when-let ((proj (project-current))) (project-root proj))
      default-directory))

(defun sz/neotree-open ()
  "Open neotree at the project root and reveal the current file."
  (interactive)
  (let ((file buffer-file-name)
        (root (sz/neotree-project-root)))
    (neotree-dir root)
    (when file (neotree-find file))))

(defun sz/neotree-toggle ()
  "Toggle a project-rooted neotree sidebar, revealing the current file."
  (interactive)
  (if (neo-global--window-exists-p)
      (neotree-hide)
    (sz/neotree-open)))

(provide 'sz-workspace)
;;; sz-workspace.el ends here
