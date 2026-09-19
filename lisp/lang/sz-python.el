;;; sz-python.el --- Python: pet -*- lexical-binding: t; -*-
;;; Commentary:
;; pet resolves each project's virtualenv and tooling for Python buffers.
;;; Code:

(use-package pet
  :ensure t
  :config
  (add-hook 'python-base-mode-hook #'pet-mode -10))

(provide 'sz-python)
;;; sz-python.el ends here
