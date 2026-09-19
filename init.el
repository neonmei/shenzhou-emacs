;;; init.el --- Main configuration entry point -*- lexical-binding: t; -*-
;;; Commentary:
;; Bootstraps elpaca, wires it into the built-in `use-package', then loads the
;; category modules from lisp/.  Real configuration lives in lisp/sz-*.el.
;;; Code:

;;;; --- Elpaca bootstrap (installer v0.12, from the elpaca manual) --------------

(defvar elpaca-core-date '(20260710))
(defvar elpaca-installer-version 0.12)
(defvar elpaca-directory (expand-file-name "elpaca/" sz-local-dir))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-sources-directory (expand-file-name "sources/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                       :ref nil :depth 1 :inherit ignore
                       :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                       :build (:not elpaca-activate)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-sources-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (<= emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let* ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                  ,@(when-let* ((depth (plist-get order :depth)))
                                                      (list (format "--depth=%d" depth) "--no-single-branch"))
                                                  ,(plist-get order :repo) ,repo))))
                  ((zerop (call-process "git" nil buffer t "checkout"
                                        (or (plist-get order :ref) "--"))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                        "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (let ((load-source-file-function nil)) (load (expand-file-name "elpaca-autoloads" repo)))))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

;;;; --- use-package integration -------------------------------------------------

;; Force normal shallow clones.  The newer elpaca default (`treeless' partial
;; clones) lazily checks out blobs, which races `elpaca-queue-dependencies'
;; ("Unable to find main elisp file") in this git/network environment.
(setq elpaca-depth 1)

;; Install use-package support and turn on `:ensure' handling.
(elpaca elpaca-use-package (elpaca-use-package-mode))
(setq use-package-always-ensure t)

;; Block until the elpaca machinery above is live, so later `:ensure nil'
;; built-ins and `require's see a fully initialised use-package.
(elpaca-wait)

;;;; --- Load configuration modules ----------------------------------------------

;; Add lisp/ and each of its category sub-directories (core/, ui/, editor/,
;; lang/, productivity/, tools/) to load-path.
(let ((lisp (expand-file-name "lisp/" user-emacs-directory)))
  (add-to-list 'load-path lisp)
  (dolist (dir (directory-files lisp t "\\`[^.]"))
    (when (file-directory-p dir)
      (add-to-list 'load-path dir))))

(setq custom-file (locate-user-emacs-file ".local/custom.el"))

;; Order matters: core defaults first, tooling last.  Each module installs its
;; packages asynchronously and does its real work in `:config' blocks, which
;; elpaca defers until the package is actually built (avoids the install race).
(defvar sz-modules
  '(;; core/
    sz-core                  ; defaults, identity/paths
    sz-sys                   ; environment, path, tramp, clipboard, macOS
    sz-encrypt               ; gpg and epa configuration
    ;; ui/
    sz-ui                    ; theme, fonts, modeline, circadian
    sz-workspace             ; SPC TAB workspaces (before sz-keys: C-c TAB refs its map), neotree
    sz-dashboard
    ;; editor/
    sz-completion            ; vertico/corfu stack, yasnippet
    sz-keys                  ; SPC / C-c leader keymaps (before meow)
    sz-editing               ; general editing
    sz-meow                  ; meow + leader wiring
    ;; lang/
    sz-langs                 ; treesit, flymake, misc modes
    sz-eglot                 ; eglot, lsp-booster, eldoc-box
    sz-python
    sz-nix
    sz-rust
    sz-go
    sz-terraform
    sz-puml
    ;; productivity/
    sz-org                   ; org core, spelling, latex, babel
    sz-vulpea                ; vulpea, journal, citar, org-roam (opt-in)
    sz-gtd                   ; GTD methodology
    ;; tools/
    sz-git                   ; magit
    sz-llm                   ; agent-shell (+ sidebar)
    sz-terminal              ; eat terminal
    sz-docs                  ; devdocs
    sz-media)                ; radio, emms, discord, winpulse
  "Ordered modules loaded from lisp/.  Also used by `sz/emacs/reload'.")

(dolist (m sz-modules) (require m))

(load custom-file 'noerror)

;;; init.el ends here
