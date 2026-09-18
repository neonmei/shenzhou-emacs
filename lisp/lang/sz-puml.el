;;; sz-puml.el --- PlantUML -*- lexical-binding: t; -*-
;;; Commentary:
;; PlantUML mode with the AWS stdlib keyword list loaded into completion.
;; Ported from Doom dev.el.
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

(provide 'sz-puml)
;;; sz-puml.el ends here
