;;; sz-encrypt.el --- GPG, EPA, and certificate tooling -*- lexical-binding: t; -*-
;;; Commentary:
;; GPG and EPA configuration, plus certificate inspection (x509-mode).
;;; Code:

(setq epa-armor t
      epg-pinentry-mode 'loopback
      epa-pinentry-mode 'loopback
      epa-file-encrypt-to (list sz-gpg)
      epa-file-select-keys nil
      epa-file-inhibit-auto-save t)

(use-package pinentry
  :ensure t
  :demand t
  :config (pinentry-start))

(use-package sops
  :ensure t
  :init
  (global-sops-mode 1))


;;;; --- Certificates ------------------------------------------------------------

(use-package x509-mode
  :ensure t
  :defer t)


;;;; --- GPG helpers -------------------------------------------------------------

(defun sz/gpg/encrypt-current ()
  "Save the current buffer as [filename].gpg and delete the original."
  (interactive)
  (let ((original-file (buffer-file-name)))
    (unless original-file
      (user-error "Buffer is not visiting a file"))
    (when (string-suffix-p ".gpg" original-file)
      (user-error "File is already encrypted"))
    (let ((new-file (concat original-file ".gpg")))
      (when (file-exists-p new-file)
        (user-error "Target file %s already exists" new-file))
      (write-file new-file)
      (delete-file original-file)
      (message "Encrypted to %s and deleted %s"
               (file-name-nondirectory new-file)
               (file-name-nondirectory original-file)))))

(defun sz/gpg/decrypt-current ()
  "Save the current buffer without the .gpg suffix and delete the original."
  (interactive)
  (let ((original-file (buffer-file-name)))
    (unless original-file
      (user-error "Buffer is not visiting a file"))
    (unless (string-suffix-p ".gpg" original-file)
      (user-error "File is not encrypted (does not end in .gpg)"))
    (let ((new-file (file-name-sans-extension original-file)))
      (when (file-exists-p new-file)
        (user-error "Target file %s already exists" new-file))
      (write-file new-file)
      (delete-file original-file)
      (message "Decrypted to %s and deleted %s"
               (file-name-nondirectory new-file)
               (file-name-nondirectory original-file)))))

(provide 'sz-encrypt)
;;; sz-encrypt.el ends here
