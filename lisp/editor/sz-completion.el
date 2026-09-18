;;; sz-completion.el --- Minibuffer and in-buffer completion -*- lexical-binding: t; -*-
;;; Commentary:
;; The modern "vertico stack" for the minibuffer plus corfu for in-buffer
;; completion.  No ivy/helm/company.  yasnippet is pointed at the bundled
;; snippets/ tree; tree-sitter modes inherit the classic-mode tables.
;;; Code:

(use-package consult
  :ensure t
  :bind (("C-s"   . consult-line)
         ("C-c b" . consult-buffer)
         ("C-c y" . consult-yank-pop)
         ("C-x 4 b" . consult-buffer-other-window)
         ("C-x C-b" . consult-buffer)
         ("C-x b" . consult-buffer)
         ("C-x r b" . consult-bookmark)
         ("M-g g" . consult-goto-line)
         ("M-g i" . consult-imenu)
         ("M-s f" . consult-find)
         ("M-s r" . consult-ripgrep))
  :init
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref))

(use-package embark
  :ensure t
  :bind (("C-." . embark-act)
         ("M-." . embark-dwim)
         ("C-h B" . embark-bindings)))

(use-package embark-consult
  :ensure t
  :after (embark consult)
  :hook (embark-collect-mode . consult-preview-at-point-mode))

;;;; --- In-buffer: corfu + cape -------------------------------------------------

(use-package corfu
  :ensure t
  :init (global-corfu-mode 1)
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.15)
  (corfu-quit-no-match 'separator)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  (corfu-preselect 'prompt)
  :config
  (corfu-popupinfo-mode 1))

(use-package kind-icon
  :after corfu
  :config
  (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))

(use-package cape
  :ensure t
  :init
  (add-hook 'completion-at-point-functions #'cape-dabbrev)
  (add-hook 'completion-at-point-functions #'cape-file)
  (add-hook 'completion-at-point-functions #'cape-elisp-block))

;;;; --- Inline completion preview (complements corfu's popup) -------------------

(use-package completion-preview
  :ensure nil
  :hook (after-init . global-completion-preview-mode)
  :bind
  ( :map completion-preview-active-mode-map
         ("M-n" . completion-preview-next-candidate)
         ("M-p" . completion-preview-prev-candidate))
  :custom
  (completion-preview-minimum-symbol-length 2) ; Show the preview already after two symbol characters
  (completion-preview-exact-match-only nil) ; If t, only show suggestion if there is only one candidate
  (completion-preview-idle-delay 0.3) ; If non-nil, wait this many idle seconds before displaying preview
  :config
  (with-eval-after-load 'org
    ;; Add Org mode's custom 'self-insert-command' to completion-previews
    (push 'org-self-insert-command completion-preview-commands))
  ;; Disable completion preview in Org tables (Emacs 31+)
  (defun my/detect-org-table ()
    "Return non-nil if point is in an Org table."
    (and (derived-mode-p 'org-mode) (org-at-table-p)))
  (add-hook 'completion-preview-inhibit-functions #'my/detect-org-table))


(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles partial-completion)))))

(use-package marginalia
  :ensure t
  :init (marginalia-mode 1))

;; TAB completes (drives corfu) when already indented.
(setq tab-always-indent 'complete
      completion-cycle-threshold 3
      text-mode-ispell-word-completion nil
      )

(use-package minibuffer
  :ensure nil
  :config
  (setq completion-show-help nil)
  (setq completion-show-inline-help nil)
  (setq completions-detailed t)
  (setq completions-format 'one-column)
  (setq completions-max-height 12)
  (setq completions-sort 'historical)
  (setq completion-auto-help t)
  (setq completion-auto-select nil
        minibuffer-visible-completions t)
  (setq completion-eager-display t)
  (setq completion-eager-update t))

(setopt completions-detailed t)
(setopt tab-always-indent 'complete)
(setopt completion-auto-help 'always)
(setopt completions-group t)

;;;; --- Snippets ----------------------------------------------------------------
(use-package yasnippet
  :ensure t
  :init
  (setq yas-snippet-dirs (list (expand-file-name "snippets" user-emacs-directory)))
  :config
  (yas-global-mode 1)
  ;; Tree-sitter modes don't derive from the classic modes, so make them pick up
  ;; the matching snippet tables.
  (add-hook 'go-ts-mode-hook   (lambda () (yas-activate-extra-mode 'go-mode)))
  (add-hook 'yaml-ts-mode-hook (lambda () (yas-activate-extra-mode 'yaml-mode))))

(provide 'sz-completion)
;;; sz-completion.el ends here
