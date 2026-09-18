;;; sz-core.el --- Sane defaults, persistence, environment -*- lexical-binding: t; -*-
;;; Commentary:
;; Editor defaults, on-disk state redirected to var/, and the daemon PATH.
;;; Code:

;;;; --- .local/ + var/ directories for generated state --------------------------

(defvar sz-local-dir)                   ; defined in early-init.el

(defun sz/local (file)
  "Return absolute path to FILE inside `sz-local-dir'."
  (expand-file-name file sz-local-dir))

(defconst sz-var-dir (expand-file-name "var/" sz-local-dir)
  "Directory for generated state we do not want tracked in git.")

(defun sz/var (file)
  "Return absolute path to FILE inside `sz-var-dir'."
  (expand-file-name file sz-var-dir))

(make-directory sz-var-dir t)           ; also creates `sz-local-dir'

(defvar sz-modules)

(defun sz/emacs/reload ()
  "Reload all sz-*.el config modules in the running Emacs."
  (interactive)
  (dolist (m sz-modules) (load (symbol-name m)))
  (when (called-interactively-p 'any)
    (message "sz/emacs/reload: reloaded %d modules" (length sz-modules))))

;;;; --- Identity & paths (from Doom core.el) ------------------------------------

(setq user-full-name "neonmei"
      user-mail-address "contact@neonmei.cloud")

(defconst sz-kaifa (expand-file-name "~/kaifa"))
(defconst sz-git   (expand-file-name "git" sz-kaifa))
(defconst sz-dir   (expand-file-name "shenzhou" sz-kaifa))
(defconst sz-org   (expand-file-name "org" sz-dir))
(defconst sz-cloud (expand-file-name "cloud" sz-dir))
(defconst sz-nix   (expand-file-name "nix" sz-dir))
(defconst sz-csl   (expand-file-name "csl-styles" sz-dir))
(defconst sz-bib   (expand-file-name "bib" sz-org))
(defconst sz-roam  (expand-file-name "roam" sz-org))
(defconst sz-dailies (expand-file-name "tier2/dailies" sz-roam))

(defconst sz-mail "releng@neonmei.cloud")
(defconst sz-gpg  "0x268415EAAD4D5FF0")

(add-hook 'elpaca-after-init-hook
          (lambda ()
            (setq gc-cons-threshold (* 64 1024 1024)
                  gc-cons-percentage 0.1)))

;;;; --- Editor defaults ---------------------------------------------------------

(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8)

(setq-default indent-tabs-mode nil
              tab-width 4
              fill-column 80)

(setopt sentence-end-double-space nil
        require-final-newline t
        create-lockfiles nil
        use-short-answers t
        ring-bell-function #'ignore
        scroll-conservatively 101
        scroll-margin 2
        delete-by-moving-to-trash t
        custom-safe-themes t)

(setq backup-directory-alist `(("." . ,(sz/var "backup/")))
      auto-save-file-name-transforms `((".*" ,(sz/var "auto-save/") t))
      version-control t
      kept-new-versions 10
      kept-old-versions 10
      delete-old-versions t
      backup-by-copying t)
(make-directory (sz/var "auto-save/") t)

(setq auto-save-list-file-prefix (sz/local "auto-save-list/.saves-")
      transient-levels-file      (sz/local "transient/levels.el")
      transient-values-file      (sz/local "transient/values.el")
      transient-history-file     (sz/local "transient/history.el")
      project-list-file          (sz/local "projects")
      bookmark-default-file      (sz/var "bookmarks"))
(make-directory (sz/local "auto-save-list/") t)
(make-directory (sz/local "transient/") t)
(with-eval-after-load 'request
  (setq request-storage-directory (sz/local "request/")))

(setq global-auto-revert-non-file-buffers t)
(add-hook 'before-save-hook #'delete-trailing-whitespace)
(column-number-mode 1)
(global-visual-line-mode 1)

;; Line numbers on by default everywhere, except viewer/REPL/special buffers.
(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode 1)
(dolist (h '(term-mode-hook vterm-mode-hook eat-mode-hook eshell-mode-hook shell-mode-hook
             pdf-view-mode-hook doc-view-mode-hook image-mode-hook
             treemacs-mode-hook compilation-mode-hook dired-mode-hook
             vundo-mode-hook Custom-mode-hook help-mode-hook))
  (add-hook h (lambda () (display-line-numbers-mode -1))))


;; Make saved scripts executable when they start with a shebang.
(add-hook 'after-save-hook #'executable-make-buffer-file-executable-if-script-p)

(provide 'sz-core)
;;; sz-core.el ends here
