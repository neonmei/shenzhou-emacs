;;; sz-diagrams.el --- Diagram languages -*- lexical-binding: t; -*-
;;; Commentary:
;; Diagram-as-code modes: PlantUML (with the AWS stdlib keyword list loaded
;; into completion, ported from Doom dev.el) and D2.
;;; Code:

(defvar sz/plantuml-stdlib-keyword-files '("assets/plantuml-stdlib-awslib14.txt")
  "Keyword files in `user-emacs-directory' to load into plantuml completions.")

(defun sz/plantuml-load-keywords (file)
  "Load keywords from FILE (one per line) into `plantuml-kwdList'."
  (let ((path (expand-file-name file user-emacs-directory)))
    (when (file-exists-p path)
      (with-temp-buffer
        (insert-file-contents path)
        (dolist (kw (split-string (buffer-string) "\n" t))
          (puthash kw t plantuml-kwdList))))))

(defun sz/plantuml-add-stdlib-keywords-a (&rest _)
  "Advice for `plantuml-init-once': load stdlib keyword files."
  (when (hash-table-p plantuml-kwdList)
    (dolist (f sz/plantuml-stdlib-keyword-files)
      (sz/plantuml-load-keywords f))))

(defun sz/plantuml-fix-capf ()
  "Use only PlantUML's own completion-at-point in this buffer."
  (setq-local completion-at-point-functions
              (list #'plantuml-completion-at-point-function)))

(use-package plantuml-mode
  :ensure t
  :mode "\\.\\(plantuml\\|pum\\|puml\\)\\'"
  :custom
  (plantuml-indent-level 2)
  :config
  (advice-add 'plantuml-init-once :after #'sz/plantuml-add-stdlib-keywords-a)
  (add-hook 'plantuml-mode-hook #'sz/plantuml-fix-capf))

(use-package d2-mode
  :ensure t
  :mode "\\.\\(d2\\)\\'"
  :custom
  (d2-flags '("--layout" "elk" "--theme" "200" "--pad" "0"))
  (d2-location "sz-d2-babel")

  :config
  ;; Teach ob-d2 to honor a per-block :flags header arg (stock ob-d2 ignores it).
  (define-advice org-babel-execute:d2 (:around (orig body params) sz/d2-flags)
    "Append the block's :flags header arg to `d2-flags' for this run."
    (let* ((extra (cdr (assq :flags params)))
           (d2-flags (append d2-flags
                             (cond ((null extra) nil)
                                   ((listp extra) extra)
                                   (t (split-string-and-unquote (format "%s" extra)))))))
      (funcall orig body params))))


(provide 'sz-diagrams)
;;; sz-diagrams.el ends here
