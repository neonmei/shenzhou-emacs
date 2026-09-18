;;; sz-gtd.el --- Getting Things Done methodology -*- lexical-binding: t; -*-
;;; Commentary:
;; Personal GTD workflow layered on top of org/agenda: agenda custom commands,
;; capture templates, refiling helpers, and pomodoro tracking.
;;; Code:

;;;; --- Agenda grouping ---------------------------------------------------------
;; Group headers carry a text-property copy of `org-agenda-mode-map', which
;; outranks minor-mode maps and so shadows meow's motion-state j/k while point
;; sits on a header.  An empty map lets the buffer's own bindings through.

(use-package org-super-agenda
  :ensure t
  :after org
  :config
  (setq org-super-agenda-header-map (make-sparse-keymap)
        org-super-agenda-groups
        '((:name "Overdue"     :deadline past :face error)
          (:name "Today"       :time-grid t :scheduled today)
          (:name "Due soon"    :deadline future)
          (:name "In progress" :todo "INPROGRESS")
          (:name "Next"        :todo "NEXT")
          (:name "Inbox"       :tag "inbox")
          (:auto-category t)))
  (org-super-agenda-mode))

(defconst sz-org-archive-file-name "archive.org"
  "Name of the archive file kept beside each agenda file.")

(defun sz/org/archive-file-p (file)
  "Return non-nil when FILE is one of the tier archives."
  (equal (file-name-nondirectory file) sz-org-archive-file-name))

(defun sz/org/agenda-dir-files ()
  "Return every org file sitting in the tiered agenda directories.
Nothing is filtered out, archives included, so this is the list to read
clocked time from: an hour counts the same whether it was logged in
inbox.org, next.org or the archive it has since been moved to."
  (mapcan (lambda (tier)
            (let ((dir (expand-file-name (format "roam/%s/agenda" tier) sz-org)))
              (when (file-directory-p dir)
                (directory-files dir t "\\.org\\'"))))
          '("tier1" "tier2" "tier3")))

(defun sz/org/agenda-file-list ()
  "Return the agenda files across all sz-org tiers.
Files named `sz-org-archive-file-name' are left out, so archived entries
never return to the agenda itself."
  (seq-remove #'sz/org/archive-file-p (sz/org/agenda-dir-files)))

(defun sz/org/update-org-agenda-files ()
  "Dynamically scan the sz-org tier directories and update `org-agenda-files'."
  (interactive)
  (setq org-agenda-files (sz/org/agenda-file-list))
  (message "Agenda files updated: %d files found." (length org-agenda-files)))

(defun sz/org/capture-tiered-agenda-file (name)
  "Prompt for a tier (default tier2) and return its agenda file NAME."
  (let ((tier (completing-read "Tier: " '("tier1" "tier2" "tier3")
                               nil t nil nil "tier2")))
    (expand-file-name (format "roam/%s/agenda/%s.org" tier name) sz-org)))


;;;; --- GTD ---------------------------------------------------------------------
(defun sz/org/gtd-save-org-buffers ()
  "Save `org-agenda-files' buffers without user confirmation."
  (interactive)
  (message "Saving org-agenda-files buffers...")
  (save-some-buffers t (lambda ()
                         (when (member (buffer-file-name) org-agenda-files)
                           t)))
  (message "Saving org-agenda-files buffers... done"))

(advice-add 'org-refile :after (lambda (&rest _) (sz/org/gtd-save-org-buffers)))

(with-eval-after-load 'org (sz/org/update-org-agenda-files))

;;;; --- Refile to agenda sibling files ------------------------------------------

(defun sz/org/agenda-sibling-file (name)
  "Return NAME (e.g. \"inbox.org\") sitting next to the current buffer's file.
Signal a `user-error' when the buffer visits no file, or NAME is missing."
  (let* ((file    (or (buffer-file-name)
                      (user-error "Current buffer is not visiting a file")))
         (sibling (expand-file-name name (file-name-directory file))))
    (unless (file-exists-p sibling)
      (user-error "No %s beside %s" name (file-name-nondirectory file)))
    sibling))

(defun sz/org/refile-to-sibling (name &optional todo-state)
  "Refile the heading at point under a target chosen in NAME (same folder).
Offers NAME's top level and its headings (to level 3) as `org-refile'
targets, so a flat file still has a destination.  When TODO-STATE is
non-nil, switch the heading to that keyword once a destination has been
chosen, so aborting the prompt leaves the heading untouched.  The
`org-refile' advice above saves the affected buffers."
  (let* ((dest (sz/org/agenda-sibling-file name))
         (org-refile-targets `((,dest :maxlevel . 3)))
         (org-refile-use-outline-path 'file)
         (org-outline-path-complete-in-steps nil)
         (rfloc (org-refile-get-location (format "Refile to %s" name))))
    (when todo-state
      (org-todo todo-state))
    (org-refile nil nil rfloc)))

(defun sz/org/refile-to-inbox ()
  "Refile the heading at point under a target chosen in inbox.org (same folder).
The heading is switched to TODO on the way in."
  (interactive)
  (sz/org/refile-to-sibling "inbox.org" "TODO"))

(defun sz/org/refile-to-next ()
  "Refile the heading at point under a target chosen in next.org (same folder).
The heading is switched to NEXT on the way in."
  (interactive)
  (sz/org/refile-to-sibling "next.org" "NEXT"))

(defun sz/org/refile-inbox-next ()
  "Refile the heading at point between inbox.org and next.org in this folder.
From inbox.org, refile into next.org as NEXT; from next.org, refile into
inbox.org as TODO.  Either direction prompts for the destination heading
\(or the file top level)."
  (interactive)
  (pcase (and (buffer-file-name)
              (file-name-nondirectory (buffer-file-name)))
    ("inbox.org" (sz/org/refile-to-next))
    ("next.org"  (sz/org/refile-to-inbox))
    (_ (user-error "Not visiting inbox.org or next.org"))))

;;;; --- Archive completed tasks -------------------------------------------------

(defun sz/org/archive--closed-subtree-p ()
  "Return non-nil when the entry at point is finished and hides no open task.
An entry qualifies when its own keyword is in `org-done-keywords' and no
heading below it carries a keyword from `org-not-done-keywords'."
  (and (member (org-get-todo-state) org-done-keywords)
       (save-excursion
         (let ((end (save-excursion (org-end-of-subtree t t) (point)))
               (open nil))
           (while (and (not open)
                       (outline-next-heading)
                       (< (point) end))
             (when (member (org-get-todo-state) org-not-done-keywords)
               (setq open t)))
           (not open)))))

(defun sz/org/archive--candidates ()
  "Return markers on every entry of the current buffer ready to be archived.
The list runs deepest first, so a finished parent is moved only once the
finished children below it have left."
  (let (found)
    (org-map-entries
     (lambda ()
       (when (sz/org/archive--closed-subtree-p)
         (push (cons (org-current-level) (point-marker)) found)))
     t)
    (mapcar #'cdr (sort (nreverse found)
                        (lambda (a b) (> (car a) (car b)))))))

(defun sz/org/archive--title ()
  "Return the title of the entry at point, normalized as an outline path.
`org-get-outline-path' drops statistics cookies and renders links, so
reading a heading the same way it reads the path recorded for that
heading's children keeps the two comparable as the cookies change."
  (car (last (org-get-outline-path t))))

(defun sz/org/archive--find-child (level title start end bare-only)
  "Return the position of the LEVEL heading named TITLE between START and END.
When BARE-ONLY is non-nil only a heading carrying no TODO keyword
matches, so an entry archived earlier is never merged into.  Return nil
when nothing matches."
  (save-excursion
    (goto-char start)
    (let ((regexp (format "^\\*\\{%d\\} " level))
          (found nil))
      (while (and (not found) (re-search-forward regexp end t))
        (beginning-of-line)
        (if (and (equal title (sz/org/archive--title))
                 (or (not bare-only) (null (org-get-todo-state))))
            (setq found (point))
          (end-of-line)))
      found)))

(defun sz/org/archive--find-or-create (path)
  "Ensure the ancestor headings named by PATH exist in the current buffer.
PATH is a list of heading titles from level 1 downwards, as returned by
`org-get-outline-path'.  Missing headings are created as bare parents.
Return a cons of the first and last position of the region holding the
children of the deepest heading in PATH; an empty PATH yields the whole
buffer."
  (let ((start (point-min))
        (end (point-max))
        (level 0))
    (dolist (title path)
      (setq level (1+ level))
      (let ((found (sz/org/archive--find-child level title start end nil)))
        (unless found
          (goto-char end)
          (unless (bolp) (insert "\n"))
          (setq found (point))
          (insert (make-string level ?*) " " title "\n"))
        (goto-char found)
        (setq start (line-beginning-position 2)
              end (save-excursion (org-end-of-subtree t t) (point)))))
    (cons start end)))

(defun sz/org/archive--split-body (body)
  "Split BODY into the text owned by the entry and its child subtrees.
BODY is everything below an entry's heading line."
  (if (string-match "^\\*+ " body)
      (cons (substring body 0 (match-beginning 0))
            (substring body (match-beginning 0)))
    (cons body "")))

(defun sz/org/archive--place (path title line body)
  "File one entry under the outline PATH of the current buffer.
TITLE is the entry's bare heading text, LINE its full heading line and
BODY the rest of its subtree.  A bare heading that an earlier run left
behind is completed in place instead of being duplicated, its own text
going below the heading and any children it still carries after the
children archived earlier."
  (let* ((level (1+ (length path)))
         (region (sz/org/archive--find-or-create path))
         (existing (sz/org/archive--find-child level title
                                               (car region) (cdr region) t)))
    (if (not existing)
        (progn
          (goto-char (cdr region))
          (unless (bolp) (insert "\n"))
          (insert line "\n" body))
      (let* ((split (sz/org/archive--split-body body))
             (own (car split))
             (children (cdr split)))
        (goto-char existing)
        (delete-region (point) (line-end-position))
        (insert line)
        (forward-line 1)
        (unless (bolp) (insert "\n"))
        (insert own)
        (unless (string-empty-p children)
          (goto-char existing)
          (org-end-of-subtree t t)
          (unless (bolp) (insert "\n"))
          (insert children))))))

(defun sz/org/archive--preamble (file)
  "Return the header for an archive file created beside FILE."
  (format "#+title: %s Archive\n#+STARTUP: content indent logdrawer\n\n"
          (capitalize
           (file-name-nondirectory
            (directory-file-name
             (file-name-directory
              (directory-file-name (file-name-directory file))))))))

(defun sz/org/archive--prepare (archive file)
  "Return the buffer visiting ARCHIVE, ready to take entries from FILE.
A file that does not exist yet is given a header naming its tier.  This
runs only once an entry is actually on its way out, so a sweep that
moves nothing leaves no empty archive behind."
  (with-current-buffer (find-file-noselect archive)
    (unless (derived-mode-p 'org-mode)
      (org-mode))
    (when (zerop (buffer-size))
      (insert (sz/org/archive--preamble file)))
    (current-buffer)))

(defun sz/org/archive--count (file)
  "Return how many entries in FILE are ready to be archived."
  (with-current-buffer (find-file-noselect file)
    (org-with-wide-buffer
     (let ((markers (sz/org/archive--candidates)))
       (dolist (marker markers) (set-marker marker nil))
       (length markers)))))

(defun sz/org/archive--file (file)
  "Move the finished entries of FILE into `sz-org-archive-file-name' beside it.
Each entry keeps the outline path it had, so the archive mirrors FILE.
Both buffers are saved when anything moved.  Return the number of
entries archived."
  (when (sz/org/archive-file-p file)
    (user-error "%s is the archive itself" (file-name-nondirectory file)))
  (let* ((archive (expand-file-name sz-org-archive-file-name
                                    (file-name-directory file)))
         (source (find-file-noselect file))
         (target nil)
         (moved 0))
    (with-current-buffer source
      (org-with-wide-buffer
       (dolist (marker (sz/org/archive--candidates))
         (goto-char marker)
         (when (and (org-at-heading-p)
                    (member (org-get-todo-state) org-done-keywords))
           (let* ((outline (org-get-outline-path t))
                  (path (butlast outline))
                  (title (car (last outline)))
                  (start (point))
                  (end (save-excursion (org-end-of-subtree t t) (point)))
                  (text (buffer-substring-no-properties start end))
                  (break (string-search "\n" text))
                  (line (if break (substring text 0 break) text))
                  (body (if break (substring text (1+ break)) "")))
             (unless (or (string-empty-p body) (string-suffix-p "\n" body))
               (setq body (concat body "\n")))
             (delete-region start end)
             (unless target
               (setq target (sz/org/archive--prepare archive file)))
             (with-current-buffer target
               (save-excursion
                 (sz/org/archive--place path title line body)))
             (setq moved (1+ moved))))
         (set-marker marker nil))))
    (when (> moved 0)
      (with-current-buffer target (save-buffer))
      (with-current-buffer source (save-buffer)))
    moved))

(defun sz/org/archive-completed (&optional file)
  "Archive the finished entries of the tier agenda files, mirroring their outline.
Every file in a tier agenda folder is swept, inbox.org and someday.org
as much as next.org, so finished work does not linger wherever it
happened to be captured.  A DONE or CANCELLED entry that hides no open
task is moved into the archive.org beside it, filed under a copy of the
heading path it came from.  A finished parent that still holds an open
task stays where it is and only its finished children move.  With a
prefix argument, read FILE and sweep that file alone."
  (interactive
   (list (when current-prefix-arg
           (read-file-name "Archive finished entries from: " nil nil t))))
  (let* ((files (if file
                    (list (expand-file-name file))
                  (sz/org/agenda-file-list)))
         (pending (apply #'+ (mapcar #'sz/org/archive--count files))))
    (cond
     ((zerop pending)
      (message "Nothing to archive"))
     ((not (y-or-n-p (format "Archive %d finished entries from %d file(s)? "
                             pending (length files))))
      (message "Archive cancelled"))
     (t
      (message "Archived %d entries into %s"
               (apply #'+ (mapcar #'sz/org/archive--file files))
               sz-org-archive-file-name)))))

;; `org-super-agenda-groups' is global, so every block below states its own
;; value -- otherwise the defaults above re-group these hand-built blocks and
;; bury their overriding headers.
(setq org-agenda-custom-commands
      '(("g" "Get Things Done (GTD)"
         ((agenda ""
                  ((org-agenda-span 'day)
                   (org-agenda-skip-function
                    '(org-agenda-skip-entry-if 'deadline))
                   (org-deadline-warning-days 0)
                   (org-agenda-overriding-header "Today")
                   (org-super-agenda-groups nil)))
          (todo "NEXT"
                ((org-agenda-skip-function
                  '(org-agenda-skip-entry-if 'deadline))
                 (org-agenda-prefix-format "  %i %-12:c [%e] ")
                 (org-agenda-overriding-header "\nNext actions\n")
                 (org-agenda-sorting-strategy '(priority-down))
                 (org-super-agenda-groups nil)))
          (tags-todo "inbox"
                     ((org-agenda-prefix-format "  %?-12t% s")
                      (org-agenda-overriding-header "\nInbox\n")
                      (org-agenda-sorting-strategy '(priority-down))
                      (org-super-agenda-groups nil)))
          (tags "CLOSED>=\"<today>\""
                ((org-agenda-overriding-header "\nCompleted today\n")
                 (org-super-agenda-groups nil)))))))

;;;; --- Capture templates -------------------------------------------------------
;; `org-capture-templates' lives in org-capture (loaded lazily), not org, so key
;; off org-capture to avoid a void-variable error when something pulls in org.
(with-eval-after-load 'org-capture
  (setq org-capture-templates
        (append org-capture-templates
                `(("g" "GTD capture")
                  ("gi" "Inbox" entry
                   (file+headline (lambda () (sz/org/capture-tiered-agenda-file "inbox"))
                                  "Captured")
                   ,(concat "* TODO %?\n" "/Entered on/ %U"))
                  ("gn" "Next" entry
                   (file+headline (lambda () (sz/org/capture-tiered-agenda-file "next"))
                                  "Captured")
                   ,(concat "* NEXT %?\n" "/Entered on/ %U"))
                  ("gg" "Next, tier2" entry
                   (file+headline ,(expand-file-name "roam/tier2/agenda/next.org" sz-org)
                                  "Captured")
                   ,(concat "* NEXT %?\n" "/Entered on/ %U"))
                  ("v" "Vulpea note (tiered)" plain
                   (file sz/vulpea/tiered-target) "%?" :unnarrowed t)
                  ("p" "Postmortem (RCA)" plain
                   (file sz/vulpea/rca-target)
                   (file ,(concat sz-org "/doc-templates/sre-rca/basic.org"))
                   :unnarrowed t)
                  ("E" "English log" entry
                   (file+head
                    (lambda () (expand-file-name (format-time-string "english/%Y/%m/%Y-%m-%d.org") sz-dailies))
                    "#+title: ES-%<%Y-%m-%d>\n#+filetags: :english:language:meet:\n")
                   "* %?")))))

;;;; --- Pomodoro ----------------------------------------------------------------

(use-package org-pomodoro
  :ensure t
  :after org
  :config
  (add-hook 'org-pomodoro-started-hook  #'sz/org/gtd-save-org-buffers)
  (add-hook 'org-pomodoro-finished-hook #'sz/org/gtd-save-org-buffers)
  (add-hook 'org-pomodoro-killed-hook   #'sz/org/gtd-save-org-buffers)
  (setq org-pomodoro-play-sounds t
        org-pomodoro-audio-player "mpv"
        org-pomodoro-finished-sound (expand-file-name "assets/bell_big.mp3" user-emacs-directory)
        org-pomodoro-short-break-sound (expand-file-name "assets/bell_small.mp3" user-emacs-directory)))



;;;; --- Activity tracking -------------------------------------------------------
;; ActivityWatch time tracking (aw-server on http://127.0.0.1:5600).
;;
;; `:demand'/`require' the package fully before enabling the globalized mode:
;; its autoload attaches an `after-change-major-mode-hook' handler, but the
;; `global-activity-watch-mode-buffers' state variable is only `defvar'd at the
;; bottom of activity-watch-mode.el.  Enabling on a partial (autoload-only) load
;; left that variable void, so every buffer switch (e.g. SPC p p) raised
;; "void variable global-activity-watch-mode-buffers".  A full load fixes it.

(use-package activity-watch-mode
  :ensure t
  :demand t
  :init
  (setq activity-watch-api-host "http://127.0.0.1:5600"
        activity-watch-project-name-default "unknown"
        activity-watch-write-interval 30)
  :config
  (require 'activity-watch-mode)
  (global-activity-watch-mode))

(provide 'sz-gtd)
;;; sz-gtd.el ends here
