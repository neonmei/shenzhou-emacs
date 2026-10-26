;;; sz-workspace.el --- Workspaces (perspective) -*- lexical-binding: t; -*-
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

(provide 'sz-workspace)
;;; sz-workspace.el ends here
