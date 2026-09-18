;;; sz-docs.el --- Documentation browsers -*- lexical-binding: t; -*-
;;; Commentary:
;; devdocs -- browse and search DevDocs.io API documentation offline inside
;; Emacs.  Fetch doc sets once with `M-x devdocs-install'; look up the thing at
;; point with SPC d h / C-c d h (`devdocs-lookup', bound in sz-keys).
;;; Code:

(use-package devdocs
  :ensure t
  :commands (devdocs-lookup devdocs-install devdocs-peruse devdocs-search))

;; exercism -- transient menu to configure tracks, download/open exercises, run
;; tests and submit.  Needs the `exercism' CLI on PATH.  Menu on SPC d e / C-c d e
;; (`exercism', bound in sz-keys).
(use-package exercism
  :ensure t
  :commands (exercism exercism-configure))

(provide 'sz-docs)
;;; sz-docs.el ends here
