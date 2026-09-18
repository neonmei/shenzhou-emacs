;;; sz-git.el --- Git tooling -*- lexical-binding: t; -*-
;;; Commentary:
;; magit, forge (issues/PRs), pr-review (line-by-line GitHub PR review) and
;; consult-gh (search across GitHub via the gh CLI).
;;; Code:

;;;; --- Git ---------------------------------------------------------------------

;; Emacs 30 bundles transient 0.7.x, but current magit needs >= 0.13.  Queue it
;; explicitly so elpaca installs the newer version instead of the built-in.
(use-package transient :ensure t :demand t)

;; ghub (forge, pr-review) reads tokens here; the default searches plaintext
;; ~/.authinfo first.
(setq auth-sources (list "~/.authinfo.gpg"))

(use-package magit
  :ensure t
  :bind (("C-x g"   . magit-status)
         ("C-c s" . magit-status)
         ("C-x M-g" . magit-dispatch)
         )
  ;; magit is its own modal UI; let it own every letter key (k=discard, etc.).
  ;; meow puts special-modes in MOTION and grabs j/k at emulation-map priority, which outranks magit's own map -- so disable meow entirely in magit buffers.
  ;; magit-section-mode rather than magit-mode: also covers forge and pr-review.
  :hook (magit-section-mode . sz/meow-disable)
  :custom
  (magit-define-global-key-bindings nil)
  (magit-diff-refine-hunk t))

(use-package forge
  :ensure t
  :after magit
  :custom (forge-database-file (sz/local "forge-database.sqlite")))

(use-package pr-review
  :ensure t
  :commands (pr-review
             pr-review-open-url
             pr-review-notification
             pr-review-search
             pr-review-search-open)
  ;; Share forge's auth-source entry rather than need a second token line.
  :custom (pr-review-ghub-auth-name 'forge))

(defun sz/git/pr-review-dwim ()
  "Review the forge topic at point in `pr-review'.
Outside a forge buffer, fall back to `pr-review''s own URL prompt."
  (interactive)
  (require 'pr-review)
  (if-let* ((topic (and (fboundp 'forge-current-topic) (forge-current-topic)))
            (url (forge-get-url topic)))
      (pr-review-open-url url)
    (call-interactively #'pr-review)))

(defun sz/git/project-status ()
  "Prompt for a project and show its Magit status buffer."
  (interactive)
  (require 'magit)
  (let* ((dir (funcall project-prompter))
         (toplevel (magit-toplevel dir)))
    (unless toplevel
      (user-error "No Git repository at %s" dir))
    (when-let* ((pr (project-current nil dir)))
      (project-remember-project pr))
    (magit-status-setup-buffer toplevel)))

(use-package diff-hl
  :ensure t
  :demand t
  :custom
  (diff-hl-draw-borders nil)
  (diff-hl-disable-on-remote t)
  :config
  (global-diff-hl-mode 1)
  (diff-hl-flydiff-mode 1)
  (add-hook 'magit-post-refresh-hook #'diff-hl-magit-post-refresh)
  (add-hook 'dired-mode-hook #'diff-hl-dired-mode))

(use-package consult-gh
  :ensure t
  ;; consult-gh-transient.el ships no autoload cookie for its own menu.
  :init (autoload 'consult-gh-transient "consult-gh-transient" nil t)
  :custom
  (consult-gh-default-clone-directory sz-git)
  (consult-gh-default-interactive-command #'consult-gh-transient)
  (consult-gh-show-preview t))

(use-package consult-gh-embark
  :ensure t
  :after (consult-gh embark)
  :config (consult-gh-embark-mode 1))

(use-package consult-gh-with-pr-review :ensure t :defer t)

;; Loaded with forge so its gh-CLI token advice is in place before forge's first
;; request.  Both modes claim `consult-gh-pr-action', so enable them in this order:
;; forge takes both actions, then pr-review takes pull requests back.
(use-package consult-gh-forge
  :ensure t
  :after forge
  :demand t
  :config
  (consult-gh-forge-mode 1)
  (when (require 'consult-gh-with-pr-review nil t)
    (consult-gh-with-pr-review-mode 1)))

(add-to-list 'savehist-additional-variables 'consult-gh--known-orgs-list)
(add-to-list 'savehist-additional-variables 'consult-gh--known-repos-list)

(with-eval-after-load 'meow
  (add-to-list 'meow-mode-state-list '(forge-post-mode . insert))
  (add-to-list 'meow-mode-state-list '(pr-review-input-mode . insert)))

(setq dired-vc-rename-file t)

(provide 'sz-git)
;;; sz-git.el ends here
