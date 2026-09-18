;;; sz-vulpea.el --- Vulpea notes, journal, GTD, citar -*- lexical-binding: t; -*-
;;; Commentary:
;; Ported from Doom vulpea.el + gtd.el + vulpea-citar.el + vulpea-capf.el.
;; Uses vulpea v2 (d12frosted), which keeps its own sqlite DB and does not need
;; org-roam.  org-roam + org-roam-ui remain available as an opt-in graph block
;; behind `sz-org-roam-enable'.
;;; Code:

;;;; --- Vulpea: tiered note helpers ---------------------------------------------

;; Forward-declare so the `let' in `sz/vulpea/find' rebinds it dynamically
;; (vulpea owns this defcustom and loads lazily :after org).
(defvar vulpea-create-default-function)

(defun sz/vulpea/pick-tier ()
  "Prompt for a roam tier (tier1/tier2/tier3)."
  (completing-read "Tier: " '("tier3" "tier2" "tier1") nil t))


(defvar sz/vulpea/categories-file "assets/vulpea-categories.txt"
  "File in `user-emacs-directory' listing roam categories, one per line.")

(defun sz/vulpea/read-categories ()
  "Read roam categories from `sz/vulpea/categories-file' in `user-emacs-directory'.
Return the non-empty, whitespace-trimmed lines, or (\"general\") when the
file is missing or empty."
  (let ((path (expand-file-name sz/vulpea/categories-file user-emacs-directory)))
    (or (and (file-exists-p path)
             (with-temp-buffer
               (insert-file-contents path)
               (split-string (buffer-string) "\n" t "[ \t\r]+")))
        '("general"))))

(defvar sz/vulpea/categories (sz/vulpea/read-categories)
  "Roam note categories filed under {tier}/{category}/.
Loaded from `sz/vulpea/categories-file'; reload with
`sz/vulpea/categories-refresh'.")

(defun sz/vulpea/categories-refresh ()
  "Reload `sz/vulpea/categories' from disk."
  (interactive)
  (setq sz/vulpea/categories (sz/vulpea/read-categories))
  (message "vulpea: %d categories loaded" (length sz/vulpea/categories)))

(defun sz/vulpea/tiered-file-name ()
  "Prompt tier/category/format and return a vulpea :file-name template string."
  (let ((tier (completing-read "Tier: " '("tier1" "tier2" "tier3")
                               nil t nil nil "tier2"))
        (cat  (completing-read "Category: " sz/vulpea/categories
                               nil nil nil nil "gongzuo"))
        (fmt  (completing-read "Format: " '("org" "org.gpg")
                               nil t nil nil "org")))
    (format "%s/%s/${slug}.%s" tier cat fmt)))

(defun sz/vulpea/tiered-target ()
  "Prompt for tier/category/format and create a vulpea note; return its path."
  (let ((title (read-string "Title: ")))
    (vulpea-note-path
     (vulpea-create title (sz/vulpea/tiered-file-name)))))

(defun sz/vulpea/find-create-defaults (_title)
  "Default params for `sz/vulpea/find': tiered file path plus a #+date head."
  (list :file-name (sz/vulpea/tiered-file-name)
        :head "#+date: %<%Y-%m-%d>"))

(defun sz/vulpea/find ()
  "Like `vulpea-find', but file new notes under {tier}/{category}/${slug}.{fmt}."
  (interactive)
  (let ((vulpea-create-default-function #'sz/vulpea/find-create-defaults))
    (call-interactively #'vulpea-find)))

(defun sz/vulpea/rca-target ()
  "Create an SRE postmortem vulpea note and return its path."
  (let ((title (read-string "Title: ")))
    (vulpea-note-path
     (vulpea-create title "sre/rca/%<%Y>/%<%m>/%<%d>-${slug}.org"
                    :tags '("sre" "rca")))))

;;;; --- Vulpea: packages & db sync ----------------------------------------------

(use-package vulpea
  :ensure t
  :after org
  :init
  (setq vulpea-db-location (sz/local "vulpea.db")
        vulpea-db-sync-directories (list sz-roam)
        vulpea-buffer-alias-property "ROAM_ALIASES"
        vulpea-db-sync-poll-interval 2
        vulpea-db-sync-scan-on-enable 'async
        vulpea-create-default-template
        '(:file-name "${timestamp}-${slug}.org"
          :head "#+date: %<%Y-%m-%d>"))
  :config
  (vulpea-db-autosync-mode +1))

(use-package vulpea-ui
  :ensure t
  :after vulpea
  :config (setq vulpea-ui-sidebar-position 'right))

;;;; --- Journal -----------------------------------------------------------------

(defun sz/vulpea/node-date ()
  "Return the time of the org node at point.
Resolves SCHEDULED, then the first active timestamp in the entry, then a
DATE property.  Returns nil when none is present."
  (org-with-point-at (point)
    (org-back-to-heading t)
    (or (org-get-scheduled-time (point))
        (let* ((end (org-entry-end-position))
               (ts (save-excursion
                     (when (re-search-forward org-ts-regexp end t)
                       (match-string 0)))))
          (and ts (org-time-string-to-time ts)))
        (let ((d (org-entry-get (point) "DATE")))
          (and d (org-time-string-to-time d))))))

(defun sz/vulpea/refile-to-journal ()
  "Move the org subtree at point into the gongzuo journal note for its date.
The destination day is `sz/vulpea/node-date' (SCHEDULED / active timestamp /
DATE property); the journal note is created if it does not exist."
  (interactive)
  (org-back-to-heading t)
  (let ((time (sz/vulpea/node-date)))
    (unless time
      (user-error "Node has no SCHEDULED, active timestamp, or DATE"))
    (let ((note (vulpea-journal-note time)))
      (org-cut-subtree)
      (vulpea-utils-with-note-sync note
        (goto-char (point-max))
        (unless (bolp) (insert "\n"))
        (org-paste-subtree 1))
      (message "Refiled to %s" (vulpea-note-title note)))))

(use-package vulpea-journal
  :ensure t
  :after (vulpea vulpea-ui)
  :config
  (setq vulpea-journal-tag "gongzuo"
        ;; Function form so :head's #+date tracks the *entry* date even when
        ;; backfilling a past day via `vulpea-journal-date'.
        vulpea-journal-default-template
        (lambda (date)
          (list
           :file-name (format-time-string "tier2/dailies/gongzuo/%Y/%m/%Y-%m-%d.org" date)
           :title     (format-time-string "BG-%Y-%m-%d" date)
           :tags      '("gongzuo" "meet")
           :head      (format-time-string "#+date: %Y-%m-%d" date)
           :body      "* Agenda\n\n* Notes\n")))
  (vulpea-journal-setup))

;;;; --- Org completion-at-point (vulpea-capf) -----------------------------------

(use-package vulpea-capf
  :ensure (:host github :repo "neonmei/vulpea-capf")
  :hook (org-mode . vulpea-capf-mode))

;;;; --- Notes graph (vulpea-graph + graph-fa2) ----------------------------------

;; ForceAtlas2 engine that renders the graph as SVG inside an Emacs buffer.
;; graph-fa2 is a hard runtime dep of vulpea-graph but is on no archive, so it
;; is installed here from the neonmei fork (adds configurable edge + label-text
;; styling on top of upstream elij/graph-fa2).  It is configured entirely through
;; the vulpea-graph options below -- no graph-fa2 variable is set directly.
(use-package graph-fa2
  :ensure (:host github :repo "neonmei/graph-fa2"))

;; `M-x vulpea-graph' draws a force-directed graph of the vulpea notes. Every
;; knob -- including the graph-fa2 appearance/layout ones -- is a vulpea-graph
;; option, applied to graph-fa2 before each render.
(use-package vulpea-graph
  :ensure (:host github :repo "neonmei/vulpea-graph")
  :after vulpea
  :commands (vulpea-graph vulpea-graph-toggle-labels)
  :init
  (setq vulpea-graph-scope            'headings         ; nodes: connected (default) | all | headings
        vulpea-graph-buffer-name       "*vulpea-graph*" ; buffer the graph renders in
        vulpea-graph-display           'bufferh         ; open: bufferh (default) | bufferv | frame | window
        ;; nodes
        vulpea-graph-node-colour       "#8653FF"        ; node fill colour, hex
        vulpea-graph-node-radius       5.0              ; node radius, SVG units
        ;; edges
        vulpea-graph-edge-colour       "#cba6f7"        ; edge stroke colour, hex
        vulpea-graph-edge-width        0.3              ; edge stroke width, SVG units
        ;; labels (only visible when show-labels is on)
        vulpea-graph-show-labels       t                ; draw node titles? (default nil)
        vulpea-graph-label-scope       'connected       ; which nodes get a title: connected (default) | all | headings
        vulpea-graph-label-colour      "#cdd6f4"        ; label text colour, hex
        vulpea-graph-label-font-size   4              ; label font size; line spacing scales with it
        vulpea-graph-label-wrap-chars  10               ; wrap a label after this many characters
        ;; layout
        vulpea-graph-spacing           80000)           ; edge rest length; bigger = notes farther apart (default 12800 ~=50px)
  ;; optional label font (nil = renderer default):
  ;; (setq vulpea-graph-label-font-family "JetBrains Mono"
  ;;       vulpea-graph-label-font-weight "bold")
  ;; escape hatch for any other graph-fa2 knob (physics / zoom / framerate):
  ;; (setq vulpea-graph-fa2-settings
  ;;       '((graph-fa2-simulation-frames   . 840)      ; layout iterations; more = more settled
  ;;         (graph-fa2-repulsion-threshold . 655360)   ; close-range repulsion floor
  ;;         (graph-fa2-horizon-threshold   . 61440)    ; boundary clamp (fixed viewBox may clip if raised)
  ;;         (graph-fa2-zoom-friction       . 0.85)))  ; scroll-zoom momentum (0..1)
  )

;;;; --- Bibliography / citar ----------------------------------------------------

(defun sz/bib/reload ()
  "Rescan sz-bib for .bib/.bibtex files and update citar + org-cite."
  (interactive)
  (let ((bibs (directory-files-recursively sz-bib (rx "." (or "bib" "bibtex") eol))))
    (setq org-cite-global-bibliography bibs
          citar-bibliography bibs)
    (when (called-interactively-p 'any)
      (message "Loaded %d bibliography files" (length bibs)))))

(setq org-cite-csl-styles-dir sz-csl)

;; Custom citar notes source backed by vulpea.  Notes link to citekeys via an
;; org file property (ROAM_REFS); file scanning is used because vulpea's db does
;; not surface ROAM_REFS through note properties.
(defvar sz/citar-vulpea-refs-property "ROAM_REFS"
  "Org file property used to store citekey refs in vulpea notes.")

(defun sz/citar-vulpea--build-table ()
  "Scan org files in sz-roam and return hash-table of citekey -> (list path)."
  (let ((table   (make-hash-table :test 'equal))
        (pattern (concat "^:" (regexp-quote sz/citar-vulpea-refs-property)
                         ":[[:space:]]+")))
    (dolist (file (directory-files-recursively sz-roam "\\.org\\'"))
      (with-temp-buffer
        (insert-file-contents file nil 0 4000)
        (goto-char (point-min))
        (when (re-search-forward pattern nil t)
          (dolist (ref (split-string (buffer-substring (point) (line-end-position))))
            (when (string-prefix-p "@" ref)
              (puthash (substring ref 1) (list file) table))))))
    table))

(defun sz/citar-vulpea--items (_citekeys)
  "Return hash-table of citekey -> (list path) for citar :items."
  (sz/citar-vulpea--build-table))

(defun sz/citar-vulpea--hasitems ()
  "Return a predicate (key -> non-nil) for citar :hasitems, or nil if no notes."
  (let ((table (sz/citar-vulpea--build-table)))
    (unless (hash-table-empty-p table)
      (lambda (citekey) (and (gethash citekey table) t)))))

(defun sz/citar-vulpea--open-note (file)
  "Open FILE (a note path returned by citar :items)."
  (find-file file))

(defun sz/citar-vulpea--create-note (key entry)
  "Create a new vulpea note for KEY using ENTRY metadata.
Prompts for a tier and files the note at {tier}/books/${slug}.org."
  (require 'vulpea)
  (let* ((title (or (cdr (assoc "title" entry)) key))
         (tier  (sz/vulpea/pick-tier))
         (note  (vulpea-create title (format "%s/books/${slug}.org" tier)
                               :properties
                               `((,sz/citar-vulpea-refs-property
                                  . ,(concat "@" key))))))
    (find-file (vulpea-note-path note))))

(use-package citar
  :ensure t
  :after org
  :config
  (sz/bib/reload)
  (citar-register-notes-source
   'vulpea
   (list :name     "Vulpea"
         :category 'file
         :items    #'sz/citar-vulpea--items
         :hasitems #'sz/citar-vulpea--hasitems
         :open     #'sz/citar-vulpea--open-note
         :create   #'sz/citar-vulpea--create-note))
  (setq citar-notes-source 'vulpea))

;;;; --- Org-roam graph ----------------------------------------------------------
;; vulpea v2 doesn't need org-roam; this adds a second indexer over sz-roam.
(defvar sz-org-roam-enable nil
  "Non-nil to also install org-roam and the org-roam-ui graph.")

(when sz-org-roam-enable
  (use-package org-roam
    :ensure t
    :init (setq org-roam-directory sz-roam
                org-roam-db-location (sz/local "org-roam.db")))
  (use-package simple-httpd :ensure t :after org-roam)
  (use-package websocket :ensure t :after org-roam)
  (use-package org-roam-ui :ensure t :after (org-roam simple-httpd websocket)))

(provide 'sz-vulpea)
;;; sz-vulpea.el ends here
