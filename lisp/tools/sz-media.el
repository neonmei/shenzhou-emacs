;;; sz-media.el --- Radio, music, presence, tracking -*- lexical-binding: t; -*-
;;; Commentary:
;; Ported from Doom media.el: eradio (mpv), EMMS+MPD, activity-watch, elcord
;; Discord presence, winpulse.  These shell out to external daemons (mpv, mpd,
;; aw-server, Discord) declared in Nix.  Bindings live in sz-keys (SPC r).
;;; Code:

;;;; --- Radio helpers (mpv IPC) -------------------------------------------------

(defvar sz-radio-station "")
(defvar sz-last-radio-station "")
(defvar sz/radio-ipc-socket
  (expand-file-name "eradio-mpv.sock" temporary-file-directory)
  "Path to the mpv IPC socket for eradio.")

(defun sz/radio/play ()
  "Select a station, play it, and display the name in the modeline."
  (interactive)
  (let* ((station (completing-read "Radio Station: " eradio-channels))
         (url (cdr (assoc station eradio-channels))))
    (eradio-play url)
    (setq sz-radio-station (format " 📻 %s " station))
    (setq sz-last-radio-station station)))

(defun sz/radio/stop ()
  "Stop the radio and clear the modeline display."
  (interactive)
  (eradio-stop)
  (setq sz-radio-station ""))

(defun sz/radio/toggle ()
  "Toggle the radio player and update the modeline."
  (interactive)
  (if (string-empty-p sz-radio-station)
      (if (string-empty-p sz-last-radio-station)
          (call-interactively 'sz/radio/play)
        (progn
          (eradio-play (cdr (assoc sz-last-radio-station eradio-channels)))
          (setq sz-radio-station (format " 📻 %s " sz-last-radio-station))))
    (sz/radio/stop)))

(defun sz/radio/mpv-command (cmd)
  "Send a raw command to the mpv IPC socket."
  (ignore-errors
    (let ((proc (make-network-process :name "mpv-ipc"
                                      :family 'local
                                      :service sz/radio-ipc-socket)))
      (process-send-string proc (concat cmd "\n"))
      (process-send-eof proc))))

(defun sz/radio/volume-up ()
  "Increase the radio volume."
  (interactive)
  (sz/radio/mpv-command "add volume 5"))

(defun sz/radio/volume-down ()
  "Decrease the radio volume."
  (interactive)
  (sz/radio/mpv-command "add volume -5"))

(defun sz/radio/toggle-mute ()
  "Toggle mute on the radio without stopping the stream."
  (interactive)
  (sz/radio/mpv-command "cycle mute"))

(defun sz/radio/cleanup-socket ()
  "Delete the eradio mpv IPC socket file."
  (when (file-exists-p sz/radio-ipc-socket)
    (delete-file sz/radio-ipc-socket)))

(use-package eradio
  :ensure t
  :init
  (setq eradio-channels
        '(("动感101 (上海，华语流行)"    . "http://ls.qingting.fm/live/274.m3u8")
          ("Love Radio (上海，情歌)"      . "http://ls.qingting.fm/live/273.m3u8")
          ("经典音乐广播 (上海)"          . "http://ls.qingting.fm/live/275.m3u8")
          ("KFM98.1 (上海，国际流行)"     . "http://ls.qingting.fm/live/891.m3u8")
          ("上海新闻广播 (上海，新闻)"    . "http://ls.qingting.fm/live/277.m3u8")
          ("上海戏剧曲艺广播 (上海)"      . "http://ls.qingting.fm/live/276.m3u8")))
  (setq eradio-player
        (list "mpv" "--no-video" "--demuxer-max-bytes=128M"
              "--cache=yes" "--cache-secs=60" "--cache-pause=yes"
              "--cache-pause-wait=15"
              (concat "--input-ipc-server=" sz/radio-ipc-socket)))
  :config
  ;; Show the station name in the modeline (visible where the mode-line renders
  ;; `global-mode-string').
  (add-to-list 'global-mode-string '(:eval sz-radio-station) t)
  (add-hook 'kill-emacs-hook #'sz/radio/cleanup-socket))

;;;; --- Music (EMMS + MPD) ------------------------------------------------------

(use-package emms
  :ensure t
  :commands (emms emms-smart-browse emms-play-directory
             emms-pause emms-stop emms-next emms-previous)
  :init
  (setq emms-directory (sz/var "emms/"))
  :config
  (require 'emms-setup)
  (emms-all)
  (setq emms-player-mpd-server-name "127.0.0.1"
        emms-player-mpd-server-port "6600"
        emms-player-list '(emms-player-mpd)
        emms-info-functions '(emms-info-mpd)
        emms-info-asynchronously t
        emms-player-mpd-music-directory "~/yinyue"
        emms-source-file-default-directory "~/yinyue")
  ;; Connect lazily; tolerate a missing MPD daemon.
  (ignore-errors (emms-player-mpd-connect))
  (ignore-errors (emms-cache-set-from-mpd-all)))

;;;; --- Discord presence (elcord) -----------------------------------------------

(use-package elcord
  :ensure t
  :init
  (setq elcord-display-buffer-details nil
        elcord-display-line-numbers nil
        elcord-use-major-mode-as-main-icon nil
        elcord-idle-message "冥想 💭"
        elcord-idle-timer 600
        elcord-show-small-icon t
        elcord-refresh-rate 60
        elcord-editor-icon "emacs_dragon_icon")
  :config
  (elcord-mode 1))

;;;; --- Window pulse ------------------------------------------------------------

(use-package winpulse
  :ensure (:host github :repo "xenodium/winpulse")
  :config (winpulse-mode +1))

(provide 'sz-media)
;;; sz-media.el ends here
