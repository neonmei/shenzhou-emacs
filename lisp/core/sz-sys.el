;;; sz-sys.el --- Environment, PATH, TRAMP, clipboard, macOS -*- lexical-binding: t; -*-
;;; Commentary:
;; Environment and TRAMP configuration, OS clipboard <-> kill-ring sync, and
;; the macOS-only keyboard, dired and fullscreen tweaks (guarded on darwin).
;;; Code:

;;;; --- Environment / PATH ------------------------------------------------------

;; Tooling is declared in Nix, so the systemd/home-manager-launched daemon
;; normally already has everything on PATH.  Keep exec-path-from-shell as a
;; safety net for the case where Emacs is started from a graphical session that
;; did not source a login shell.  Use "-l" (login) not "-i" (interactive): the
;; interactive rc is slow and can hang the daemon.
(use-package exec-path-from-shell
  :ensure t
  :demand t
  :config
  (setq exec-path-from-shell-arguments '("-l"))
  (dolist (v '("PATH" "MANPATH" "LSP_USE_PLISTS" "SSH_AUTH_SOCK"
               "GOPATH" "GOFLAGS" "GOPROXY" "ANTHROPIC_API_KEY"))
    (add-to-list 'exec-path-from-shell-variables v))
  (when (or (daemonp) (memq window-system '(pgtk x mac ns)))
    (exec-path-from-shell-initialize)))

;; NixOS profile dirs, explicit (faithful to Doom system.el; harmless if
;; exec-path-from-shell already supplied them).
(dolist (d '("/run/current-system/sw/bin"
             "/etc/profiles/per-user/neonmei/bin"
             "/nix/var/nix/profiles/default/bin"
             "~/.nix-profile/bin" "~/.cargo/bin" "~/.go/bin"))
  (add-to-list 'exec-path (expand-file-name d)))

;;;; --- TRAMP -------------------------------------------------------------------

(setq tramp-copy-size-limit (* 1024 1024)
      tramp-verbose 2
      tramp-persistency-file-name (sz/var "tramp")
      remote-file-name-inhibit-locks t
      auto-revert-remote-files nil
;      tramp-use-scp-direct-remote-copying t
      tramp-use-connection-share t ; I use ControlMaster
;      tramp-connection-timeout 300   ; default 60s is too short for SSO
      tramp-histfile-override t
      )

(with-eval-after-load 'tramp
  (dolist (d '("/run/current-system/sw/bin"
               "/etc/profiles/per-user/neonmei/bin"
               "/nix/var/nix/profiles/default/bin"
               "~/.nix-profile/bin" "~/.cargo/bin" "~/.go/bin"))
    (add-to-list 'tramp-remote-path d)))

;;;; --- Clipboard ---------------------------------------------------------------
;; Keep the OS clipboard and the kill-ring in sync in both directions across a
;; daemon that serves both GUI and terminal frames, on macOS and Wayland.
;;
;; Cut  (kill -> clipboard): native in GUI (ns/pgtk); `clipetty' (OSC 52) in TTY.
;; Paste(clipboard -> yank): native in GUI; a shell-out helper in TTY, since a
;;                           terminal Emacs cannot read the clipboard directly.

(setq select-enable-clipboard t              ; keep native GUI sync explicit
      save-interprogram-paste-before-kill t ; don't lose an app's copy on kill
      meow-use-clipboard t)

(defun sz/os-clipboard-paste ()
  "Return the OS clipboard text for `interprogram-paste-function'.
In GUI frames defer to the native selection; in a TTY shell out to the
platform clipboard tool (pbpaste on macOS, wl-paste on Wayland)."
  (cond
   ((display-graphic-p) (gui-selection-value))
   ((eq system-type 'darwin)
    (let ((s (shell-command-to-string "pbpaste")))
      (unless (string-empty-p s) s)))
   ((executable-find "wl-paste")
    (let ((s (shell-command-to-string "wl-paste --no-newline")))
      (unless (string-empty-p s) s)))))

(setq interprogram-paste-function #'sz/os-clipboard-paste)

;; TTY cut path (OSC 52).  No-op in GUI frames, where native handles cut.
(use-package clipetty
  :ensure t
  :hook (after-init . global-clipetty-mode))

;;;; --- macOS -------------------------------------------------------------------
(when (eq system-type 'darwin)
  ;; Command -> Meta (so Cmd-x is M-x, familiar on the Mac and easy on the pinky);
  ;; left Option -> Super; right Option left as-is so accented characters still
  ;; type.  Both the ns build (`ns-*') and the emacs-mac port (`mac-*') are set --
  ;; only one set exists at a time, and `setq' on the absent one is harmless.

  (setq ns-command-modifier       'meta
        ns-option-modifier        'super
        ns-right-option-modifier  'none
        mac-command-modifier      'meta
        mac-option-modifier       'super
        mac-right-option-modifier 'none)

  ;; macOS ships BSD `ls', which lacks `--dired'.  Prefer GNU coreutils `gls' when
  ;; present (declared in Nix); otherwise tell dired not to pass `--dired'.

  (if (executable-find "gls")
      (setq insert-directory-program "gls"
            dired-use-ls-dired t)
    (setq dired-use-ls-dired nil))

  (add-to-list 'default-frame-alist '(fullscreen . fullboth))
  (setq ns-use-native-fullscreen t))

(provide 'sz-sys)
;;; sz-sys.el ends here
