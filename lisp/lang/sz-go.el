;;; sz-go.el --- Go tooling: run, coverage, debug -*- lexical-binding: t; -*-
;;; Commentary:
;; Go run helpers, go-carpet/`go tool cover' coverage views, lcov overlays
;; (cov), go-impl, and remote Delve (dape) debug configs.  Ported from Doom
;; dev.el.
;;; Code:

(use-package go-mode :ensure t :mode "\\.go\\'")

;;;; --- Go: run -----------------------------------------------------------------

(defun sz/go/run ()
  "Run the current Go file using `go run' relative to the project root."
  (interactive)
  (let* ((project-root (project-root (project-current t)))
         (current-file (buffer-file-name))
         (relative-path (file-relative-name current-file project-root))
         (default-directory project-root))
    (compile (format "go run ./%s" relative-path))))

(defun sz/go/save-run ()
  "Save the current buffer and run it with `sz/go/run'."
  (interactive)
  (save-buffer)
  (sz/go/run))

;;;; --- Go: coverage ------------------------------------------------------------

(defun sz/gocov--run (direction size-type size)
  "Run go-carpet and display the output."
  (let* ((project-root (project-root (project-current t)))
         (current-file (buffer-file-name))
         (relative-path (file-relative-name current-file project-root))
         (compilation-buffer-name-function
          (lambda (_mode) "*go-carpet*"))
         (display-buffer-alist
          `((,(lambda (buffer-name _action) (string-match-p "\\*go-carpet\\*" buffer-name))
             (display-buffer-in-direction)
             (direction . ,direction)
             (,size-type . ,size)))))
    (compile (format "go-carpet -file %s" relative-path))
    (when-let ((window (get-buffer-window "*go-carpet*")))
      (select-window window)
      (goto-char (point-min)))))

(defun sz/go/cov-below ()
  "Display coverage for current file below."
  (interactive)
  (sz/gocov--run 'below 'window-height 0.3))

(defun sz/go/cov-right ()
  "Display coverage for current file on the right side."
  (interactive)
  (sz/gocov--run 'right 'window-width 0.5))

(defun sz/go/cov-functions (coverage-file)
  "Show function coverage using `go tool cover -func'."
  (interactive (list (if current-prefix-arg
                         (read-file-name "Coverage file: ")
                       "coverage.out")))
  (let ((default-directory (project-root (project-current t))))
    (compile (format "go tool cover -func=%s" coverage-file))))

(defun sz/cov/cov-from-project-root (dir _name)
  "Return the newest lcov tracefile under the project root, or nil."
  (when-let* ((proj (project-current nil dir))
              (root (project-root proj))
              (hits (append
                     (file-expand-wildcards (expand-file-name "*.lcov" root))
                     (file-expand-wildcards (expand-file-name "lcov.info" root))
                     (file-expand-wildcards (expand-file-name "coverage/lcov.info" root)))))
    (car (sort hits #'file-newer-than-file-p))))

(defun sz/cov/fringe-to-right (fringe)
  "Move cov's FRINGE indicator to the right fringe."
  (let ((spec (get-text-property 0 'display fringe)))
    (if (eq (car-safe spec) 'left-fringe)
        (propertize fringe 'display (cons 'right-fringe (cdr spec)))
      fringe)))

(use-package cov
  :ensure t
  :hook ((go-mode go-ts-mode) . cov-mode)
  :init
  (setq cov-coverage-mode t
        cov-lcov-patterns (list #'sz/cov/cov-from-project-root))
  :config
  (advice-add 'cov--get-fringe :filter-return #'sz/cov/fringe-to-right))

(use-package go-impl :ensure t)

;;;; --- Debugger (dape) ---------------------------------------------------------

(defun sz/go/dape-make-config (name port)
  "Generate a remote Go debug config with NAME and PORT."
  `(,(intern name)
    modes (go-mode go-ts-mode)
    command "dlv"
    command-args ("dap" "--listen" ,(format "127.0.0.1:%d" port))
    host "127.0.0.1"
    port ,port
    :type "go"
    :request "launch"
    :program ,(file-remote-p default-directory 'localname)))

(use-package dape
  :ensure t
  :config
  (add-to-list 'dape-configs (sz/go/dape-make-config "dlv-tramp"   9999))
  (add-to-list 'dape-configs (sz/go/dape-make-config "dlv-tramp-2" 9998)))

(provide 'sz-go)
;;; sz-go.el ends here
