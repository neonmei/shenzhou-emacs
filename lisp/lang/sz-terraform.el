;;; sz-terraform.el --- Terraform: dialects, terraform-ls, eldoc -*- lexical-binding: t; -*-
;;; Commentary:
;; terraform-mode plus thin derived modes for each Terraform file dialect, so
;; eglot declares the right LSP languageId to terraform-ls.  Carries the
;; terraform-ls initializationOptions (prefill, validate-on-save) and wrappers
;; for the server's custom commands.  Plain .hcl (packer/nomad/vault) stays in
;; hcl-mode with no language server.
;;; Code:

(declare-function eglot-execute "eglot")
(declare-function eglot-path-to-uri "eglot")
(declare-function eglot--current-server-or-lose "eglot")
(declare-function eglot-current-server "eglot")
(declare-function eglot-reconnect "eglot")
(declare-function terraform-format-buffer "terraform-mode")
(declare-function terraform-mode "terraform-mode")
(declare-function hcl-mode "hcl-mode")
(defvar terraform-mode-map)
(defvar eglot-server-programs)

;;;; --- Dialect modes -----------------------------------------------------------

(defmacro sz-terraform--define-dialect (mode lighter language-id)
  "Define MODE, a `terraform-mode' child shown as LIGHTER, speaking LANGUAGE-ID."
  `(progn
     (define-derived-mode ,mode terraform-mode ,lighter
       ,(format "Terraform dialect declared to terraform-ls as `%s'." language-id))
     (put ',mode 'eglot-language-id ,language-id)))

(sz-terraform--define-dialect sz-terraform-vars-mode   "Terraform[vars]"   "terraform-vars")
(sz-terraform--define-dialect sz-terraform-test-mode   "Terraform[test]"   "terraform-test")
(sz-terraform--define-dialect sz-terraform-mock-mode   "Terraform[mock]"   "terraform-mock")
(sz-terraform--define-dialect sz-terraform-stack-mode  "Terraform[stack]"  "terraform-stack")
(sz-terraform--define-dialect sz-terraform-deploy-mode "Terraform[deploy]" "terraform-deploy")

;;;; --- Language server ------------------------------------------------------

(defconst sz-terraform--servers
  '((terraform-ls
     :program "terraform-ls"
     :prefix  "terraform-ls"
     :init    "terraform.init"
     :validate "terraform.validate"
     :language-ids ((sz-terraform-vars-mode   . "terraform-vars")
                    (sz-terraform-test-mode   . "terraform-test")
                    (sz-terraform-mock-mode   . "terraform-mock")
                    (sz-terraform-stack-mode  . "terraform-stack")
                    (sz-terraform-deploy-mode . "terraform-deploy")
                    (terraform-mode           . "terraform")))
    (tofu-ls
     :program "tofu-ls"
     :prefix  "tofu-ls"
     :init    "tofu.init"
     :validate "tofu.validate"
     :language-ids ((sz-terraform-vars-mode   . "opentofu-vars")
                    (sz-terraform-test-mode   . "opentofu")
                    (sz-terraform-mock-mode   . "opentofu")
                    (sz-terraform-stack-mode  . "opentofu")
                    (sz-terraform-deploy-mode . "opentofu")
                    (terraform-mode           . "opentofu"))))
  "Per-server wiring.  `terraform-mode' must stay last in :language-ids:
`eglot--languageId' returns the first entry the buffer's mode derives from,
and every dialect mode derives from `terraform-mode'.

tofu-ls advertises only \"opentofu\" and \"opentofu-vars\"; the Terraform-only
dialects fall back to \"opentofu\" there.")

(defcustom sz-terraform-lsp 'terraform-ls
  "Language server used for Terraform/OpenTofu buffers."
  :type '(choice (const :tag "terraform-ls (HashiCorp Terraform)" terraform-ls)
                 (const :tag "tofu-ls (OpenTofu)" tofu-ls))
  :initialize #'custom-initialize-default
  :set (lambda (sym val)
         (set-default sym val)
         (sz-terraform--register-server))
  :group 'tools)

(defun sz-terraform--spec ()
  "Return the wiring for the selected server."
  (alist-get sz-terraform-lsp sz-terraform--servers))

(defun sz-terraform--ours-p (entry)
  "Non-nil if ENTRY of `eglot-server-programs' is one we registered."
  (let ((modes (car entry)))
    (and (consp modes)
         (seq-find (lambda (m) (eq (car-safe m) 'sz-terraform-vars-mode)) modes))))

(defun sz-terraform--register-server ()
  "Point `eglot-server-programs' at the server named by `sz-terraform-lsp'."
  (when (boundp 'eglot-server-programs)
    (let ((spec (sz-terraform--spec)))
      (setq eglot-server-programs
            (cons (cons (mapcar (lambda (cell)
                                  (list (car cell) :language-id (cdr cell)))
                                (plist-get spec :language-ids))
                        (list (plist-get spec :program) "serve"
                              :initializationOptions #'sz/terraform-eglot-options))
                  (seq-remove #'sz-terraform--ours-p eglot-server-programs))))))

(defun sz/terraform/use-server (server)
  "Switch Terraform buffers to SERVER and restart any running session."
  (interactive
   (list (intern (completing-read
                  "Language server: "
                  (mapcar (lambda (s) (symbol-name (car s))) sz-terraform--servers)
                  nil t nil nil (symbol-name sz-terraform-lsp)))))
  (customize-set-variable 'sz-terraform-lsp server)
  (when-let* ((s (eglot-current-server))) (eglot-reconnect s))
  (message "Terraform language server: %s" server))

(defcustom sz-terraform-ignored-directories nil
  "Extra directory names the language server skips while indexing.
Both servers already ignore .git, .idea, .vscode, terraform.tfstate.d and
.terragrunt-cache, and reject \".terraform\" outright because they read that
directory to resolve module calls."
  :type '(repeat string)
  :group 'tools)

(defun sz/terraform-eglot-options (_server)
  "Build the language server's initializationOptions for SERVER."
  (append (list :experimentalFeatures (list :prefillRequiredFields t
                                            :validateOnSave t)
                :validation (list :enableEnhancedValidation t))
          (when sz-terraform-ignored-directories
            (list :indexing (list :ignoreDirectoryNames
                                  (vconcat sz-terraform-ignored-directories))))))

;;;; --- Server commands ---------------------------------------------------------

(defun sz-terraform--execute (command)
  "Run the server COMMAND against the current module directory.
COMMAND is the unprefixed name; both servers namespace their commands
under the server's own name (e.g. \"terraform-ls.terraform.init\")."
  (let ((spec (sz-terraform--spec)))
    (eglot-execute (eglot--current-server-or-lose)
                   (list :command (concat (plist-get spec :prefix) "." command)
                         :arguments
                         (vector (concat "uri="
                                         (eglot-path-to-uri
                                          (file-name-as-directory
                                           (expand-file-name default-directory)))))))))

(defun sz-terraform--show (name data)
  "Pretty-print DATA into a buffer called NAME."
  (with-current-buffer (get-buffer-create name)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert (pp-to-string data))
      (goto-char (point-min)))
    (special-mode)
    (display-buffer (current-buffer))))

(defun sz/terraform/init ()
  "Run the server's init command (terraform init / tofu init)."
  (interactive)
  (sz-terraform--execute (plist-get (sz-terraform--spec) :init))
  (message "%s: init done" sz-terraform-lsp))

(defun sz/terraform/validate ()
  "Run the server's validate command (terraform validate / tofu validate)."
  (interactive)
  (sz-terraform--execute (plist-get (sz-terraform--spec) :validate))
  (message "%s: validate done" sz-terraform-lsp))

(defun sz/terraform/module-providers ()
  "Show the providers required by the current module."
  (interactive)
  (sz-terraform--show "*terraform providers*"
                      (sz-terraform--execute "module.providers")))

(defun sz/terraform/module-calls ()
  "Show the modules called by the current module."
  (interactive)
  (sz-terraform--show "*terraform module calls*"
                      (sz-terraform--execute "module.calls")))

(defun sz/terraform/module-callers ()
  "Show the modules that call the current module."
  (interactive)
  (sz-terraform--show "*terraform module callers*"
                      (sz-terraform--execute "module.callers")))

;;;; --- Buffer setup ------------------------------------------------------------

(defun sz-terraform--setup ()
  "Compose hover and signature help in eldoc for Terraform buffers."
  (setq-local eldoc-documentation-strategy #'eldoc-documentation-compose))

;;;; --- Package -----------------------------------------------------------------

(use-package terraform-mode
  :ensure t
  :demand t
  :hook (terraform-mode . sz-terraform--setup)
  :bind ( :map terraform-mode-map
          ("C-c C-f" . terraform-format-buffer)
          ("C-c C-i" . sz/terraform/init)
          ("C-c C-v" . sz/terraform/validate)
          ("C-c C-p" . sz/terraform/module-providers))
  :config
  (dolist (entry '(("\\.tofu\\'"                . terraform-mode)
                   ("\\.tfvars\\(\\.json\\)?\\'" . sz-terraform-vars-mode)
                   ("\\.tftest\\.hcl\\'"         . sz-terraform-test-mode)
                   ("\\.tfmock\\.hcl\\'"         . sz-terraform-mock-mode)
                   ("\\.tfstack\\.hcl\\'"        . sz-terraform-stack-mode)
                   ("\\.tfdeploy\\.hcl\\'"       . sz-terraform-deploy-mode)
                   ("\\.pkr\\.hcl\\'"            . hcl-mode)))
    (add-to-list 'auto-mode-alist entry))

  (with-eval-after-load 'eglot (sz-terraform--register-server)))


(use-package terraform-doc
  :ensure t
  :defer t)

(provide 'sz-terraform)
;;; sz-terraform.el ends here
