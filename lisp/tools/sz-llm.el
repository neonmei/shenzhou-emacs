;;; sz-llm.el --- AI agent tooling -*- lexical-binding: t; -*-
;;; Commentary:
;; agent-shell (ACP-based agent client).
;;; Code:

;;;; --- AI agent shell ----------------------------------------------------------

;; agent-shell needs shell-maker >= 0.90.1, newer than stable MELPA, so install
;; shell-maker + acp + agent-shell from VC.  The Claude Code ACP agent CLI it
;; drives is provided on PATH via Nix.
(use-package shell-maker
  :ensure (:host github :repo "xenodium/shell-maker"))

(use-package acp
  :ensure (:host github :repo "xenodium/acp.el"))

(use-package agent-shell
  :ensure (:host github :repo "xenodium/agent-shell")
  :after (shell-maker acp)
  :custom
;   (agent-shell-anthropic-authentication)
    (agent-shell-preferred-agent-config '(preselect . claude-code))
    (agent-shell-anthropic-make-authentication :login t)
    (agent-shell-kimi-default-model-id "kimi-code/k3")
    (agent-shell-anthropic-default-model-id "opus")
    (agent-shell-session-restore-verbosity 'full)
;   (agent-shell-prefer-viewport-interaction t)
)

;; Sidebar add-on (bindings live in sz-keys: SPC a / C-c a).
(use-package agent-shell-sidebar
  :ensure (:host github :repo "cmacrae/agent-shell-sidebar")
  :after agent-shell)

(use-package agent-recall
  :ensure t
  :config
  (setq agent-recall-search-paths '("~/gongzuo" "~/kaifa/shenzhou")))

(provide 'sz-llm)
;;; sz-llm.el ends here
