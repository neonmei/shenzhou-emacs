;;; sz-meow.el --- Modal editing with meow -*- lexical-binding: t; -*-
;;; Commentary:
;; meow modal editing, QWERTY layout -- no evil.  SPC is a leader: ported Doom
;; prefixes (project/notes/radio/agents/dev, defined in sz-keys.el) hang off it,
;; while meow's keypad fallback keeps `SPC x'->C-x etc.  meow only rebinds plain
;; letter keys in normal state, so every C-/M- chord still works as in vanilla
;; Emacs and the minibuffer (vertico/consult) is untouched.  See README.md.
;;; Code:

(defun sz/meow-setup ()
  "Define the QWERTY meow keymaps (upstream reference layout)."
  (setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)
  (meow-motion-define-key
   '("j" . meow-next)
   '("k" . meow-prev)
   '("<escape>" . ignore))
  (meow-leader-define-key
   ;; SPC j runs the original j command in MOTION state.
   '("j" . "H-j")
   ;; Use SPC (0-9) for digit arguments.
   '("1" . meow-digit-argument)
   '("2" . meow-digit-argument)
   '("3" . meow-digit-argument)
   '("4" . meow-digit-argument)
   '("5" . meow-digit-argument)
   '("6" . meow-digit-argument)
   '("7" . meow-digit-argument)
   '("8" . meow-digit-argument)
   '("9" . meow-digit-argument)
   '("0" . meow-digit-argument)
   '("/" . meow-keypad-describe-key)
   '("?" . meow-cheatsheet)
   ;; Ported Doom leader prefixes (keymaps defined in sz-keys.el).
   '("TAB" . sz-workspace-map)     ; workspaces (sz-workspace.el); TTY sends TAB,
   '("<tab>" . sz-workspace-map)   ; GUI sends <tab>
   '("p" . sz-project-map)
   '("n" . sz-notes-map)
   '("r" . sz-radio-map)
   '("a" . org-agenda)
   '("d" . sz-dev-map)
   '("t" . sz-toggle-map)
   '("i" . sz-insert-map)
   '("m" . sz-mc-map)
   '("g" . sz-git-map)
   '("/" . project-find-regexp)
   )
  (meow-normal-define-key
   '("0" . meow-expand-0)
   '("9" . meow-expand-9)
   '("8" . meow-expand-8)
   '("7" . meow-expand-7)
   '("6" . meow-expand-6)
   '("5" . meow-expand-5)
   '("4" . meow-expand-4)
   '("3" . meow-expand-3)
   '("2" . meow-expand-2)
   '("1" . meow-expand-1)
   '("-" . negative-argument)
   '(";" . meow-reverse)
   '("," . meow-inner-of-thing)
   '("." . meow-bounds-of-thing)
   '("[" . meow-beginning-of-thing)
   '("]" . meow-end-of-thing)
   '("a" . meow-append)
   '("A" . meow-open-below)
   '("b" . meow-back-word)
   '("B" . meow-back-symbol)
   '("c" . meow-change)
   '("d" . meow-delete)
   '("D" . meow-backward-delete)
   '("e" . meow-next-word)
   '("E" . meow-next-symbol)
   '("f" . meow-find)
   '("g" . meow-cancel-selection)
   '("G" . meow-grab)
   '("h" . meow-left)
   '("H" . meow-left-expand)
   '("i" . meow-insert)
   '("I" . meow-open-above)
   '("j" . meow-next)
   '("J" . meow-next-expand)
   '("k" . meow-prev)
   '("K" . meow-prev-expand)
   '("l" . meow-right)
   '("L" . meow-right-expand)
   '("m" . meow-join)
   '("n" . meow-search)
   '("o" . meow-block)
   '("O" . meow-to-block)
   '("p" . meow-yank)
   '("q" . meow-quit)
   '("Q" . meow-goto-line)
   '("r" . meow-replace)
   '("R" . meow-swap-grab)
   '("s" . meow-kill)
   '("t" . meow-till)
   '("u" . meow-undo)
   '("U" . meow-undo-in-selection)
   '("v" . meow-visit)
   '("w" . meow-mark-word)
   '("W" . meow-mark-symbol)
   '("x" . meow-line)
   '("X" . meow-goto-line)
   '("y" . meow-save)
   '("Y" . meow-sync-grab)
   '("z" . meow-pop-selection)
   '("'" . repeat)
   '("<escape>" . ignore)))

(use-package meow
  :ensure t
  :demand t
  :init
  ;; SPC g / SPC m are leader prefixes (git / multiple-cursors), so move the
  ;; keypad's reserved modifier prefixes off them: C-M- -> Z, M- -> M.
  (setq meow-keypad-ctrl-meta-prefix ?Z
        meow-keypad-meta-prefix ?M)
  :config
  (sz/meow-setup)
  (meow-global-mode 1))

(defun sz/meow-disable ()
  "Turn meow off in the current buffer."
  (meow-mode -1))


(provide 'sz-meow)
;;; sz-meow.el ends here
