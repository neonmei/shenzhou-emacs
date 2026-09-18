;;; sz-dashboard.el --- Provides startup dashboard -*- lexical-binding: t; -*-
;;; Commentary:
;;; This file shows important information at a glance.
;;; Code:

;; use-package with package.el:
(use-package dashboard
  :ensure t
  :config
  (dashboard-setup-startup-hook)

  (defface sz/dashboard-priority-a
    '((t :inherit error :weight bold))
    "Face for the [#A] dashboard priority badge."
    :group 'dashboard)

  (defface sz/dashboard-priority-b
    '((t :inherit warning :weight bold))
    "Face for the [#B] dashboard priority badge."
    :group 'dashboard)

  (defface sz/dashboard-priority-c
    '((t :inherit success :weight bold))
    "Face for the [#C] dashboard priority badge."
    :group 'dashboard)

  (defface sz/dashboard-priority-d
    '((t :inherit font-lock-function-name-face :weight bold))
    "Face for the [#D] dashboard priority badge."
    :group 'dashboard)

  (defun sz/dashboard-agenda-priority-badge (el)
    "Return a fixed-width \"[#X] \" badge for agenda entry EL.
Entries with no explicit priority cookie get blank padding of the same
rendered width, which under org-modern is four `org-modern-label'
columns rather than four default ones.  The badge is colored per
priority level."
    (let ((letter (get-text-property 0 'sz/dashboard-agenda-priority-char el)))
      (if letter
          (concat (propertize
                   (format "[#%c]" letter)
                   'face (pcase letter
                           (?A 'sz/dashboard-priority-a)
                           (?B 'sz/dashboard-priority-b)
                           (?C 'sz/dashboard-priority-c)
                           (?D 'sz/dashboard-priority-d)
                           (_  'shadow)))
                  " ")
        (concat (if (bound-and-true-p global-org-modern-mode)
                    (propertize "    " 'face 'org-modern-label)
                  "    ")
                " "))))

  (defun sz/dashboard-agenda-colored-tags (tags)
    "Color each of TAGS with the face `org-tag-faces' gives it."
    (mapcar (lambda (tag) (propertize tag 'face (org-get-tag-face tag))) tags))

  ;; The dashboard builds its entries with `org-agenda-format-item' but is not an
  ;; agenda buffer, so nothing ever runs `org-modern-agenda' over it.  Two things
  ;; are missing: the regexps org-modern keys its TODO labels off (buffer-local
  ;; to each agenda file, and not added by `org-agenda-format-item'), and the
  ;; call itself.

  (defun sz/dashboard-agenda-org-modern-props (fn &rest args)
    "Stamp the entry FN formats from ARGS with props the dashboard drops.
The todo regexps are what `org-modern-agenda' keys its labels off.  The
priority character is read before FN runs, while point is still on the
headline: `dashboard-agenda-priority' cannot carry it, since
`org-get-priority' maps a missing cookie onto `org-priority-default' and
so reports the same number for [#D] as for no priority at all."
    (let* ((priority (save-match-data
                       (let ((heading (org-get-heading t t nil t)))
                         (and (string-match org-priority-regexp heading)
                              (org-priority-to-value (match-string 2 heading))))))
           (item (apply fn args)))
      (add-text-properties 0 (length item)
                           (list 'org-todo-regexp org-todo-regexp
                                 'org-not-done-regexp org-not-done-regexp
                                 'sz/dashboard-agenda-priority-char priority)
                           item)
      item))

  (advice-remove 'dashboard-agenda-entry-format
                 #'sz/dashboard-agenda-org-modern-props)
  (advice-add 'dashboard-agenda-entry-format :around
              #'sz/dashboard-agenda-org-modern-props)

  (defun sz/dashboard-org-modern ()
    "Give the dashboard's agenda entries the org-modern agenda look.
`org-modern-agenda' reads those regexps at the start of each line, but
dashboard indents entries behind a widget and a priority badge, so spread
them out to the line start first.  Priority colors come from the global
`org-modern-priority-faces' (sz-org.el), shared with org buffers and the agenda."
    (when (bound-and-true-p global-org-modern-mode)
      (require 'org-modern)
      (let ((inhibit-read-only t))
        (save-excursion
          (goto-char (point-min))
          (while (not (eobp))
            (when-let* ((pos (text-property-not-all (pos-bol) (pos-eol)
                                                    'org-todo-regexp nil)))
              (add-text-properties
               (pos-bol) (pos-eol)
               (list 'org-todo-regexp (get-text-property pos 'org-todo-regexp)
                     'org-not-done-regexp (get-text-property pos 'org-not-done-regexp))))
            (forward-line 1)))
        (org-modern-agenda))))

  (add-hook 'dashboard-mode-hook #'sz/dashboard-org-modern)

  (defun sz/dashboard-insert-gtd-next (list-size)
    "Insert up to LIST-SIZE NEXT actions into the dashboard, sorted by priority."
    (require 'org-agenda)
    (let ((dashboard-match-agenda-entry "TODO=\"NEXT\"")
          (dashboard-filter-agenda-entry #'dashboard-filter-agenda-by-todo)
          (dashboard-agenda-prefix-format " %-12:c ")
          (dashboard-agenda-sort-strategy '(priority-up)))
      (dashboard-insert-section
       "NEXT Actions:"
       (sort (dashboard-get-agenda) (dashboard-agenda--sort-function))
       list-size
       'gtd-next
       "n"
       `(lambda (&rest _)
          (let ((file  (get-text-property 0 'dashboard-agenda-file ,el))
                (point (get-text-property 0 'dashboard-agenda-loc  ,el)))
            (funcall dashboard-agenda-action file point)))
       (concat (sz/dashboard-agenda-priority-badge el) el))))

  (defun sz/dashboard-insert-gtd-inbox (list-size)
    "Insert up to LIST-SIZE unprocessed Inbox items into the dashboard, sorted by priority."
    (require 'org-agenda)
    (let ((dashboard-match-agenda-entry "inbox")
          (dashboard-filter-agenda-entry #'dashboard-filter-agenda-by-todo)
          (dashboard-agenda-prefix-format " %-12:c ")
          (dashboard-agenda-sort-strategy '(priority-up)))
      (dashboard-insert-section
       "Inbox:"
       (sort (dashboard-get-agenda) (dashboard-agenda--sort-function))
       list-size
       'gtd-inbox
       "i"
       `(lambda (&rest _)
          (let ((file  (get-text-property 0 'dashboard-agenda-file ,el))
                (point (get-text-property 0 'dashboard-agenda-loc  ,el)))
            (funcall dashboard-agenda-action file point)))
       (concat (sz/dashboard-agenda-priority-badge el) el))))

  (defun sz/dashboard-clocktable--entry (path node)
    "Return the clocktable entry for PATH carrying the merged time of NODE.
The level is taken from PATH so the row is indented at the depth it
actually sits at in the merged tree."
    (let ((entry (nth 1 node)))
      (list (length path) (nth 1 entry) (nth 2 entry) (nth 3 entry)
            (nth 0 node) (nth 5 entry))))

  (defun sz/dashboard-clocktable--flatten (path nodes)
    "Return the entry at PATH in NODES followed by its descendants, in tree order."
    (let ((node (gethash path nodes)))
      (cons (sz/dashboard-clocktable--entry path node)
            (mapcan (lambda (child) (sz/dashboard-clocktable--flatten child nodes))
                    (reverse (nth 2 node))))))

  (defun sz/dashboard-clocktable-merge (tables)
    "Fold the entries of TABLES into one tree, summing the time of shared paths.
TABLES come from `org-clock-get-table-data', so an entry reads
\(LEVEL HEADLINE TAGS TIMESTAMP TIME PROPS).  Rows whose outline path
matches are reported once with their times added, which is what makes a
task and the archive it was moved to count as one heading.  Children
keep the order in which they were first met."
    (let ((nodes (make-hash-table :test #'equal))
          (roots nil))
      (dolist (table tables)
        (let ((stack nil))
          (dolist (entry (nth 2 table))
            (let* ((parent (seq-take stack (1- (nth 0 entry))))
                   (path (append parent (list (nth 1 entry))))
                   (node (gethash path nodes)))
              (setq stack path)
              (if node
                  (setcar node (+ (nth 0 node) (or (nth 4 entry) 0)))
                (setq node (list (or (nth 4 entry) 0) entry nil))
                (puthash path node nodes)
                (let ((up (and parent (gethash parent nodes))))
                  (if up
                      (setcar (cddr up) (cons path (nth 2 up)))
                    (push path roots))))))))
      (mapcan (lambda (path) (sz/dashboard-clocktable--flatten path nodes))
              (nreverse roots))))

  (defun sz/dashboard-clocktable-formatter (ipos tables params)
    "Write a clocktable at IPOS that reads TABLES as a single tree.
PARAMS is handed on to `org-clocktable-write-default' unchanged apart
from the merge, so every other clocktable option keeps working."
    (org-clocktable-write-default
     ipos
     (list (list nil
                 (apply #'+ (mapcar #'cadr tables))
                 (sz/dashboard-clocktable-merge tables)))
     params))

  (defun sz/dashboard-clocktable-string (maxlevel)
    "Return a fontified clocktable of this week's clocked time, up to MAXLEVEL.
The scope is every file in the tier agenda folders, archives included,
so an hour counts the same wherever it was logged and stays counted once
`sz/org/archive-completed' has moved the task out.  The total row is
dropped; return nil when nothing was clocked this week."
    (require 'org-clock)
    (with-temp-buffer
      (org-mode)
      (org-dblock-write:clocktable
       (list :scope (sz/org/agenda-dir-files)
             :formatter #'sz/dashboard-clocktable-formatter
             :maxlevel maxlevel :block 'thisweek
             :link nil :hidefiles t :fileskip0 t :header ""))
      (goto-char (point-min))
      (when (re-search-forward
             (concat "^|[ \t]*\\*Total time\\*[ \t]*|[ \t]*\\*\\(.+?\\)\\*[ \t]*|.*\n"
                     "\\(?:|[-+|]+\n\\)?")
             nil t)
        (unless (equal (match-string 1) "0:00")
          (replace-match "")
          (org-table-align)
          (font-lock-ensure)
          (string-trim-right (buffer-string))))))

  (defun sz/dashboard-clocking-string ()
    "Return the running clock as \"heading (duration)\", or nil when idle."
    (require 'org-clock)
    (when (org-clocking-p)
      (format "▶ %s (%s)"
              (substring-no-properties org-clock-heading)
              (org-duration-from-minutes (org-clock-get-clocked-time)))))

  (defun sz/dashboard-insert-clocktable (maxlevel)
    "Insert this week's clocktable into the dashboard, summarizing up to MAXLEVEL.
The running clock, if any, is shown above the table as a link to its task."
    (dashboard-insert-heading "Clocked" nil (dashboard-heading-icon 'clocktable))
    (let ((running (sz/dashboard-clocking-string))
          (table (sz/dashboard-clocktable-string maxlevel))
          (indent (make-string (or standard-indent tab-width 4) ?\s)))
      (when running
        (insert "\n" indent)
        (widget-create 'item
                       :tag running
                       :action (lambda (&rest _) (org-clock-goto))
                       :button-face 'success
                       :mouse-face 'highlight
                       :help-echo "Jump to the running clock"
                       :button-prefix ""
                       :button-suffix ""
                       :format "%[%t%]"))
      (when table
        (dolist (line (split-string table "\n"))
          (insert "\n" indent line)))
      (unless (or running table)
        (insert (propertize "\n    --- No items ---" 'face 'dashboard-no-items-face)))))

  (add-to-list 'dashboard-item-generators '(gtd-next   . sz/dashboard-insert-gtd-next))
  (add-to-list 'dashboard-item-generators '(gtd-inbox  . sz/dashboard-insert-gtd-inbox))
  (add-to-list 'dashboard-item-generators '(clocktable . sz/dashboard-insert-clocktable))
  (setq dashboard-banner-logo-title "Welcome to Shenzhou"
        dashboard-startup-banner (expand-file-name "assets/banner.png" user-emacs-directory)
        dashboard-startup-banner-height 100
        dashboard-center-content t
        dashboard-vertically-center-content t
        dashboard-navigation-cycle t
        dashboard-agenda-tags-format #'sz/dashboard-agenda-colored-tags
        dashboard-items '((projects   . 5)
                          (bookmarks  . 5)
                          (gtd-next   . 10)
                          (gtd-inbox  . 10)
                          (clocktable . 3)
                          (registers  . 5)
                          ))

  (setq initial-buffer-choice
        (lambda ()
          (dashboard-refresh-buffer)
          (get-buffer dashboard-buffer-name)))
  )

(provide 'sz-dashboard)
;;; sz-dashboard.el ends here
