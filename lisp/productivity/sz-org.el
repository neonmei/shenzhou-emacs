;;; sz-org.el --- Org core: display, tasks, spelling, export -*- lexical-binding: t; -*-
;;; Commentary:
;; Ported from Doom org-general.el: GPG/beamer helpers, hunspell bilingual
;; spelling, org display/tasks/LaTeX, and babel.  The notes/GTD/vulpea layer
;; lives in sz-vulpea.el and sz-gtd.el.
;;; Code:


;;;; --- Beamer present helpers --------------------------------------------------

(defun sz/org-beamer-present/beamerpresenter ()
  "Export org file to beamer PDF and open with beamerpresenter."
  (interactive)
  (let ((pdf-file (org-beamer-export-to-pdf)))
    (when pdf-file
      (start-process "beamerpresenter" nil "beamerpresenter" pdf-file))))

(defun sz/org-beamer-present/pdfpc ()
  "Export org file to beamer PDF and open with pdfpc using speaker notes."
  (interactive)
  (let ((pdf-file (org-beamer-export-to-pdf)))
    (when pdf-file
      (start-process "pdfpc" nil "pdfpc" "-n" "right" "-w" "both" pdf-file))))

;;;; --- Spelling (hunspell, bilingual es_ES,en_US) ------------------------------

(with-eval-after-load 'ispell
  (setenv "LANG" "en_US.UTF-8")
  (setq ispell-program-name "hunspell"
        ispell-dictionary "es_ES,en_US"
        ispell-personal-dictionary "~/.hunspell_personal")
  (ispell-set-spellchecker-params)
  (ispell-hunspell-add-multi-dic "es_ES,en_US"))

(add-hook 'org-mode-hook  #'flyspell-mode)
(add-hook 'text-mode-hook #'flyspell-mode)

(use-package flyspell-correct
  :ensure t
  :after flyspell
  :bind
  (:map flyspell-mouse-map
        ("RET"     . flyspell-correct-at-point)
        ([mouse-1] . flyspell-correct-at-point)))

;;;; --- Org: general ------------------------------------------------------------

(setq org-directory sz-org
      org-crypt-key sz-gpg
      org-id-locations-file (sz/local "org-id-locations")
      org-tags-exclude-from-inheritance '("crypt"))

;;;; --- Org: display ------------------------------------------------------------

(setq org-startup-indented t
      org-startup-with-inline-images t
      org-pretty-entities t
      org-hide-emphasis-markers t
      org-fontify-whole-heading-line t
      org-fontify-done-headline t
      org-fontify-quote-and-verse-blocks t
      org-startup-folded 'showall
      org-hide-block-startup t
      ;; org-modern renders tags as labels flush against the headline text.
      org-auto-align-tags nil
      org-tags-column 0
      org-agenda-tags-column 0
      org-ellipsis "…")

(use-package org-modern
  :ensure t
  :after org
  :config
  ;; Mauve tag chips.  Inherited rather than hardcoded so the color follows the
  ;; active theme; `:inverse-video' fills the label with it.
  (set-face-attribute 'org-modern-tag nil
                      :inherit '(font-lock-keyword-face org-modern-label)
                      :foreground 'unspecified
                      :background 'unspecified
                      :weight 'semibold
                      :inverse-video t)
  (global-org-modern-mode))

;;;; --- Org: tasks & LaTeX ------------------------------------------------------

(with-eval-after-load 'org
  (require 'org-crypt)
  (org-crypt-use-before-save-magic)
  (setq org-hierarchical-todo-statistics t
        org-agenda-block-separator ""
        org-log-into-drawer t
        org-return-follows-link t
        org-log-done 'time
        org-log-redeadline 'time
        org-log-reschedule 'time
        org-log-note-clock-out t
        org-clock-clocked-in-display 'mode-line
        org-priority-lowest  ?E
        org-priority-default ?D
        org-priority-highest ?A
        org-priority-faces '((?A . error) (?B . warning) (?C . success)
                             (?D . shadow) (?E . shadow))
        org-modern-priority-faces
        '((?A . (:inherit (error   org-modern-priority)))
          (?B . (:inherit (warning org-modern-priority)))
          (?C . (:inherit (success org-modern-priority)))
          (?D . (:inherit (font-lock-function-name-face org-modern-priority)))
          (t  . (:inherit (shadow  org-modern-priority))))
        org-todo-keywords
        '((sequence "TODO(t!)" "NEXT(n!)" "INPROGRESS(i!)" "HOLD(h@/!)"
                    "|" "DONE(d)" "CANCELLED(c@)"))
        org-latex-listings 'minted
        org-image-actual-width '(0.7))
  (setq org-format-latex-options (plist-put org-format-latex-options :scale 1.5)))

(with-eval-after-load 'ox-latex
  (add-to-list 'org-latex-packages-alist '("" "minted"))
  (setq org-latex-pdf-process
        '("latexmk -shell-escape -bibtex -f -pdf -%latex -interaction=nonstopmode -output-directory=%o %f")))

;;;; --- Org: babel & export ------------------------------------------------------

(setq ob-mermaid-cli-path "mmdc")
(setq org-plantuml-exec-mode 'plantuml)
(setq org-confirm-babel-evaluate nil)

(use-package ob-mermaid :ensure t :after org)

(use-package gnuplot :ensure t)
(use-package gnuplot-mode :ensure t :mode "\\.gp\\'")

(with-eval-after-load 'org
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t) (shell . t) (python . t) (mermaid . t) (gnuplot . t)
     (plantuml . t)))
  (add-hook 'org-babel-after-execute-hook #'org-link-preview-refresh))

(use-package ox-hugo   :ensure t :after ox)
(use-package ox-gfm    :ensure t :after ox)
(use-package ox-pandoc :ensure t :after ox)
(use-package citeproc :ensure t)

(provide 'sz-org)
;;; sz-org.el ends here
