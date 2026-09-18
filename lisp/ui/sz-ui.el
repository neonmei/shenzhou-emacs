;;; sz-ui.el --- Theme, fonts, icons, modeline -*- lexical-binding: t; -*-
;;; Commentary:
;; Visual layer.  Tuned for a pgtk daemon: fonts are applied per-frame because
;; the daemon has no frame at startup and pgtk needs a live frame to resolve
;; font specs.
;;; Code:

;;;; --- Theme -------------------------------------------------------------------

(use-package catppuccin-theme
  :ensure t
  :defer t
  :init
  ;; Must be set before the theme file is loaded.  Flavors: latte frappe macchiato mocha.
  (setq catppuccin-flavor 'macchiato))

(use-package kusanagi-theme
  :ensure t
  :defer t)

(use-package circadian
  :ensure t
  :demand t
  :config
  (setq calendar-latitude  -34.56351
        calendar-longitude -58.45729
        circadian-themes '((:sunrise . catppuccin)
                           (:sunset  . kusanagi)))
  (if after-init-time
      (circadian-setup)
    (add-hook 'elpaca-after-init-hook #'circadian-setup))
  (when (daemonp)
    (add-hook 'server-after-make-frame-hook #'circadian-setup)))

(setq ibuffer-human-readable-size t
      view-lossage-auto-refresh t)

;;;; --- Frame title -------------------------------------------------------------

(defun sz/frame-title--project (dir)
  "Name of the project containing DIR, or nil.
Remote DIRs are only probed over an already-open connection."
  (unless (and (file-remote-p dir) (not (file-remote-p dir nil t)))
    (let ((last-coding-system-used last-coding-system-used))
      (when-let* ((pr (project-current nil dir)))
        (project-name pr)))))

(defun sz/frame-title ()
  "Frame title: \"HOST :: PROJECT :: BUFFER\", omitting absent parts."
  (with-current-buffer (if (minibufferp)
                           (window-buffer (minibuffer-selected-window))
                         (current-buffer))
    (string-replace
     "%" "%%"
     (string-join (delq nil (list (file-remote-p default-directory 'host)
                                  (sz/frame-title--project default-directory)
                                  (buffer-name)))
                  " | "))))

(setq frame-title-format '(:eval (sz/frame-title))
      icon-title-format  frame-title-format)

(setopt window-combination-resize t)
(setopt split-window-preferred-direction 'longest)
(pixel-scroll-precision-mode)

;;;; --- Fonts (pgtk / daemon aware) ---------------------------------------------

(defvar sz-font-fixed "JetBrains Mono"
  "Monospace family for default and `fixed-pitch' faces.")
(defvar sz-font-variable "Fira Sans"
  "Proportional family for the `variable-pitch' face.")
(defvar sz-font-height
  (if (string= (system-name) "Netrunner") 160 110)
  "Default face height (1/10 pt).  Larger on the hi-dpi \"Netrunner\" host.")

(defun sz/set-fonts (&rest _)
  "Apply font faces.  Safe to call once a real frame exists."
  (when (display-graphic-p)
    (set-face-attribute 'default nil
                        :font sz-font-fixed :height sz-font-height :weight 'light)
    (set-face-attribute 'fixed-pitch nil :font sz-font-fixed)
    (set-face-attribute 'variable-pitch nil :font sz-font-variable)))

(if (daemonp)
    ;; Re-apply for each client frame (pgtk resolves fonts against the frame).
    (add-hook 'server-after-make-frame-hook #'sz/set-fonts)
  (add-hook 'elpaca-after-init-hook #'sz/set-fonts))

;;;; --- Big-font toggle & UI zoom -----------------------------------------------

(defvar sz-big-font-height (round (* sz-font-height 1.7))
  "Default face height (1/10 pt) when `sz/big-font-mode' is enabled.")

(define-minor-mode sz/big-font-mode
  "Toggle a larger default font for presentations / pairing (Doom's big-font)."
  :global t :init-value nil
  (set-face-attribute 'default nil
                      :height (if sz/big-font-mode sz-big-font-height sz-font-height)))

;; Zoom the *entire UI* (every buffer + minibuffer), not just one buffer.  This
;; is built-in on Emacs 29+; it is also bound to C-x C-M-= / C-x C-M-- /
;; C-x C-M-0 by default.  `text-scale-adjust' (C-x C-=) zooms only one buffer.
(defalias 'sz/zoom-in    (lambda () (interactive) (global-text-scale-adjust 1)))
(defalias 'sz/zoom-out   (lambda () (interactive) (global-text-scale-adjust -1)))
(defalias 'sz/zoom-reset (lambda () (interactive) (global-text-scale-adjust 0)))

;; Global zoom chords.  `C--' otherwise defaults to `negative-argument'; the
;; digit-argument prefixes still cover that need.  meow leaves C-/M- chords
;; untouched, so these work in every state.
(global-set-key (kbd "C-=") #'sz/zoom-in)
(global-set-key (kbd "C--") #'sz/zoom-out)

;;;; --- Icons -------------------------------------------------------------------

;; Glyph fonts are provided via Nix (nerd-fonts.jetbrains-mono), so there is no
;; need to run `nerd-icons-install-fonts'.
(use-package nerd-icons
  :ensure t
  :demand t)

(use-package nerd-icons-completion
  :ensure t
  :after marginalia
  :config
  (nerd-icons-completion-mode)
  (add-hook 'marginalia-mode-hook #'nerd-icons-completion-marginalia-setup))

(use-package nerd-icons-corfu
  :ensure t
  :after corfu
  :config
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))

(use-package nerd-icons-dired
  :ensure t
  :hook (dired-mode . nerd-icons-dired-mode))


; NOTE: Toggle horizontal vs vertical
(use-package transpose-frame :ensure t)
;;;; --- Modeline ----------------------------------------------------------------

;; mood-line: lightweight, independent of Doom, configurable, icon-capable.
;; Alternatives if you ever want to swap (one use-package block each):
;;   - nano-modeline   : ultra-minimal, header-line style
;;   - doom-modeline   : richest, but pulls the Doom look
;;   - vanilla         : hand-roll `mode-line-format'
(use-package mood-line
  :ensure t
  :demand t
  :config
  ;; Unicode glyphs render in any font; the fira-code set needs Fira Code
  ;; ligature glyphs.  Set here (not :init) so the variable is loaded first.
  (setq mood-line-glyph-alist mood-line-glyphs-unicode)
  (mood-line-mode 1))

(with-eval-after-load 'mood-line
  (load "mood-line-segment-vc" nil t)
  (load "mood-line-segment-checker" nil t))

(provide 'sz-ui)
;;; sz-ui.el ends here
