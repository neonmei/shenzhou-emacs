;;; early-init.el --- Pre-GUI bootstrap -*- lexical-binding: t; -*-
;;; Commentary:
;; Loaded before the package system and the first frame.  On a daemon this
;; runs at daemon startup; client frames inherit the result.
;;; Code:

;; Single configurable root for all generated runtime state (elpaca, var/,
;; caches, ...).  Defined here because eln-cache below and `elpaca-directory'
;; in init.el both run before sz-core.el loads.  Override with $SZ_LOCAL_DIR.
(defvar sz-local-dir
  (or (getenv "SZ_LOCAL_DIR")
      (expand-file-name ".local/" user-emacs-directory))
  "Base directory for generated runtime/state files.")

;; Defer garbage collection during startup for speed.  Reset to sane values
;; on `elpaca-after-init-hook' in sz-core.el.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; We use elpaca, not package.el.
(setq package-enable-at-startup nil)

;; Keep native-comp artifacts out of the tracked repo.
(setq native-comp-async-report-warnings-errors 'silent)
(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (expand-file-name "var/eln-cache/" sz-local-dir)))

;; Suppress chrome before the first frame is drawn (no flicker).
(setq default-frame-alist
      '((tool-bar-lines . 0)
        (menu-bar-lines . 0)
        (vertical-scroll-bars . nil)
        (horizontal-scroll-bars . nil)))
(setq tool-bar-mode nil
      menu-bar-mode nil
      scroll-bar-mode nil)

(setq frame-inhibit-implied-resize t
      frame-resize-pixelwise t
      inhibit-startup-screen t
      initial-scratch-message nil
      inhibit-x-resources t)

(provide 'early-init)
;;; early-init.el ends here
