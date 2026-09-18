;;; sz-keys.el --- Leader keymaps (SPC / C-c) -*- lexical-binding: t; -*-
;;; Commentary:
;; Prefix keymaps for the ported Doom leader.  meow's leader is bound to these
;; in sz-meow (`meow-leader-define-key'), and they are also attached to
;; `mode-specific-map' so the same trees are reachable as `C-c <p>' chords.
;;
;; Leaf commands may belong to packages that load later; keymaps hold symbols
;; resolved at key-press time, so binding them here (before those builds) is safe.
;;; Code:

(define-prefix-command 'sz-project-map)
(define-prefix-command 'sz-file-map)
(define-prefix-command 'sz-notes-map)
(define-prefix-command 'sz-vulpea-map)
(define-prefix-command 'sz-radio-map)
(define-prefix-command 'sz-agent-map)
(define-prefix-command 'sz-dev-map)
(define-prefix-command 'sz-toggle-map)
(define-prefix-command 'sz-insert-map)
(define-prefix-command 'sz-mc-map)
(define-prefix-command 'sz-crypt-map)
(define-prefix-command 'sz-git-map)
(define-prefix-command 'sz-gh-map)

;;;; --- SPC p : project (was the editor.el `map! :leader' project block) --------

(define-key sz-project-map "f" #'project-find-file)
(define-key sz-project-map "p" #'project-switch-project)
(define-key sz-project-map "b" #'project-switch-to-buffer)
(define-key sz-project-map "d" #'project-dired)
(define-key sz-project-map "c" #'project-compile)
(define-key sz-project-map "k" #'project-kill-buffers)
(define-key sz-project-map "s" #'project-shell)
(define-key sz-project-map "t" #'eat-project-other-window)
(define-key sz-project-map "e" #'eat-project-other-window)
(define-key sz-project-map "r" #'sz/go/run)
(define-key sz-project-map "g" #'sz/git/project-status)
(define-key sz-project-map "o" #'sz/neotree-toggle)
(define-key sz-project-map "O" #'sz/neotree-open)   ; reveal current file / re-root
(define-key sz-project-map "a" sz-agent-map)   ; SPC p a -> AI agents (see below)

;;;; --- SPC f : files -----------------------------------------------------------

(define-key sz-file-map "f" #'dired)
(define-key sz-file-map "d" #'dired-jump)
(define-key sz-file-map "r" #'consult-recent-file)
(define-key sz-file-map "s" #'save-buffer)
(define-key sz-file-map "y" #'sz/yank-file-path)
(define-key sz-file-map "Y" #'sz/yank-file-path-relative)

;;;; --- SPC n : notes  (n r -> vulpea) ------------------------------------------

(define-key sz-notes-map "r" sz-vulpea-map)
(define-key sz-notes-map "c" #'org-capture)
(define-key sz-notes-map "a" #'org-agenda)
(define-key sz-notes-map "i" #'org-id-get-create)  ; org ID for heading at point
(define-key sz-notes-map "A" #'sz/org/archive-completed)

(define-key sz-vulpea-map "f" #'sz/vulpea/find)
(define-key sz-vulpea-map "i" #'vulpea-insert)
(define-key sz-vulpea-map "b" #'vulpea-find-backlink)
(define-key sz-vulpea-map "R" #'sz/vulpea/refile-to-journal)
(define-key sz-vulpea-map "r" #'sz/org/refile-inbox-next)  ; SPC n r r -> inbox<->next
(define-key sz-vulpea-map "s" #'vulpea-ui-sidebar-toggle)
(define-key sz-vulpea-map "j" #'vulpea-journal-today)
(define-key sz-vulpea-map "n" #'vulpea-journal-next)
(define-key sz-vulpea-map "p" #'vulpea-journal-previous)
(define-key sz-vulpea-map "c" #'calendar)
(define-key sz-vulpea-map "@" #'citar-open)

;;;; --- SPC r : radio -----------------------------------------------------------

(define-key sz-radio-map "p" #'sz/radio/play)
(define-key sz-radio-map "s" #'sz/radio/stop)
(define-key sz-radio-map "t" #'sz/radio/toggle)
(define-key sz-radio-map "+" #'sz/radio/volume-up)
(define-key sz-radio-map "-" #'sz/radio/volume-down)
(define-key sz-radio-map "m" #'sz/radio/toggle-mute)

;;;; --- SPC p a : AI agents -----------------------------------------------------
;; Map attached to `sz-project-map' above; agenda now owns the top-level SPC a.

(define-key sz-agent-map "a" #'agent-shell)
(define-key sz-agent-map "c" #'agent-shell-anthropic-start-claude-code)
(define-key sz-agent-map "1" #'agent-shell-sidebar-toggle)
(define-key sz-agent-map "2" #'agent-shell-sidebar-reset)
(define-key sz-agent-map "3" #'agent-shell-sidebar-change-provider)

;;;; --- SPC t : toggles / view --------------------------------------------------

(define-key sz-toggle-map "z" #'writeroom-mode)      ; zen / distraction-free
(define-key sz-toggle-map "b" #'sz/big-font-mode)    ; big presentation font
(define-key sz-toggle-map "=" #'sz/zoom-in)          ; zoom whole UI in
(define-key sz-toggle-map "+" #'sz/zoom-in)
(define-key sz-toggle-map "-" #'sz/zoom-out)         ; zoom whole UI out
(define-key sz-toggle-map "0" #'sz/zoom-reset)       ; reset UI zoom
(define-key sz-toggle-map "l" #'display-line-numbers-mode)
(define-key sz-toggle-map "v" #'visual-line-mode)
(define-key sz-toggle-map "s" #'flyspell-mode)                ; toggle spellcheck
(define-key sz-toggle-map "S" #'flyspell-correct-at-point)    ; correct typo at point

;;;; --- SPC d : dev -------------------------------------------------------------

(define-key sz-dev-map "r" #'sz/go/run)
(define-key sz-dev-map "R" #'sz/go/save-run)
(define-key sz-dev-map "b" #'sz/go/cov-below)
(define-key sz-dev-map "w" #'sz/go/cov-right)
(define-key sz-dev-map "f" #'sz/go/cov-functions)
(define-key sz-dev-map "d" #'dape)
(define-key sz-dev-map "h" #'devdocs-lookup)
(define-key sz-dev-map "e" #'exercism)                 ; exercism action menu
(define-key sz-dev-map "k" #'eldoc-box-help-at-point)  ; childframe doc at point
(define-key sz-dev-map "a" #'eglot-code-actions)       ; LSP code actions

;;;; --- SPC i : insert ----------------------------------------------------------

(define-key sz-insert-map "s" #'yas-insert-snippet)

;;;; --- SPC m : multiple cursors ------------------------------------------------

(define-key sz-mc-map "l" #'mc/edit-lines)
(define-key sz-mc-map "n" #'mc/mark-next-like-this)
(define-key sz-mc-map "p" #'mc/mark-previous-like-this)
(define-key sz-mc-map "a" #'mc/mark-all-like-this)
(define-key sz-mc-map "d" #'mc/mark-all-dwim)
(define-key sz-mc-map "r" #'mc/mark-all-in-region)

;;;; --- SPC g : git (magit / forge / pr-review) ---------------------------------

(define-key sz-git-map "g" #'magit-status)
(define-key sz-git-map "G" #'magit-dispatch)
(define-key sz-git-map "f" #'magit-file-dispatch)
(define-key sz-git-map "b" #'magit-blame)
(define-key sz-git-map "l" #'magit-log-buffer-file)
(define-key sz-git-map "'" #'forge-dispatch)
(define-key sz-git-map "n" #'forge-list-notifications)
(define-key sz-git-map "p" #'forge-list-pullreqs)
(define-key sz-git-map "i" #'forge-list-issues)
(define-key sz-git-map "c" #'forge-create-pullreq)
(define-key sz-git-map "F" #'forge-pull)               ; fetch topics, not git pull
(define-key sz-git-map "o" #'forge-browse)
(define-key sz-git-map "r" #'sz/git/pr-review-dwim)
(define-key sz-git-map "s" #'pr-review-search)
(define-key sz-git-map "h" sz-gh-map)

;;;; --- SPC g h : github search (consult-gh) ------------------------------------

(define-key sz-gh-map "h" #'consult-gh-transient)
(define-key sz-gh-map "r" #'consult-gh-search-repos)
(define-key sz-gh-map "i" #'consult-gh-search-issues)
(define-key sz-gh-map "p" #'consult-gh-search-prs)
(define-key sz-gh-map "c" #'consult-gh-search-code)
(define-key sz-gh-map "d" #'consult-gh-dashboard)
(define-key sz-gh-map "n" #'consult-gh-notifications)
(define-key sz-gh-map "f" #'consult-gh-find-file)
(define-key sz-gh-map "C" #'consult-gh-repo-clone)

;;;; --- SPC e : crypt / certificates --------------------------------------------

(define-key sz-crypt-map "x" #'x509-dwim)
(define-key sz-crypt-map "c" #'x509-viewcert)
(define-key sz-crypt-map "r" #'x509-viewreq)
(define-key sz-crypt-map "l" #'x509-viewcrl)
(define-key sz-crypt-map "k" #'x509-viewkey)
(define-key sz-crypt-map "p" #'x509-viewpublickey)
(define-key sz-crypt-map "7" #'x509-viewpkcs7)
(define-key sz-crypt-map "a" #'x509-viewasn1)
(define-key sz-crypt-map "s" #'x509-swoop)
(define-key sz-crypt-map "E" #'sz/gpg/encrypt-current)
(define-key sz-crypt-map "D" #'sz/gpg/decrypt-current)

;;;; --- Attach prefixes to C-c (mode-specific-map) ------------------------------
;; These mirror the SPC leader as C-c chords (SPC c <k> reaches them via keypad
;; too).  meow exposes the same prefixes on SPC via `meow-leader-define-key' in
;; sz-editing.

(define-key mode-specific-map (kbd "TAB") sz-workspace-map)  ; workspaces (sz-workspace.el)
(define-key mode-specific-map "p" sz-project-map)
(define-key mode-specific-map "f" sz-file-map)
(define-key mode-specific-map "n" sz-notes-map)
(define-key mode-specific-map "r" sz-radio-map)
(define-key mode-specific-map "a" #'org-agenda)
(define-key mode-specific-map "D" #'dashboard-open)
(define-key mode-specific-map "d" sz-dev-map)
(define-key mode-specific-map "e" sz-crypt-map)
(define-key mode-specific-map "t" sz-toggle-map)
(define-key mode-specific-map "i" sz-insert-map)
(define-key mode-specific-map "m" sz-mc-map)
(define-key mode-specific-map "g" sz-git-map)

;;;; --- which-key labels --------------------------------------------------------

(with-eval-after-load 'which-key
  (which-key-add-key-based-replacements
    "C-c TAB" "workspace" "SPC TAB" "workspace"
    "C-c p" "project"  "SPC p" "project"
    "C-c p o" "neotree" "SPC p o" "neotree"
    "C-c p O" "neotree-here" "SPC p O" "neotree-here"
    "C-c f" "files"    "SPC f" "files"
    "C-c f y" "yank file path" "SPC f y" "yank file path"
    "C-c f Y" "yank file path (relative)" "SPC f Y" "yank file path (relative)"
    "C-c n" "notes"    "SPC n" "notes"
    "C-c n r" "vulpea" "SPC n r" "vulpea"
    "C-c n r r" "refile" "SPC n r r" "refile"
    "C-c r" "radio"    "SPC r" "radio"
    "C-c a" "agenda"   "SPC a" "agenda"
    "C-c D" "dashboard" "SPC D" "dashboard"
    "C-c p a" "agents" "SPC p a" "agents"
    "C-c p g" "magit status" "SPC p g" "magit status"
    "C-c p t" "terminal (other window)" "SPC p t" "terminal (other window)"
    "C-c p e" "terminal (split)" "SPC p e" "terminal (split)"
    "C-c d" "dev"      "SPC d" "dev"
    "C-c e" "crypt"    "SPC e" "crypt"
    "C-c e x" "x509 dwim" "SPC e x" "x509 dwim"
    "C-c t" "toggle"   "SPC t" "toggle"
    "C-c i" "insert"   "SPC i" "insert"
    "C-c m" "cursors"  "SPC m" "cursors"
    "C-c n i" "org-id-get-create" "SPC n i" "org-id-get-create"
    "C-c n A" "archive completed" "SPC n A" "archive completed"
    "C-c g" "git"      "SPC g" "git"
    "C-c g h" "github" "SPC g h" "github"))


(provide 'sz-keys)
;;; sz-keys.el ends here
