(deftheme dark-monochrome "A dark and monochrome theme created from scratch.")

(custom-theme-set-faces
 'dark-monochrome

 '(default
   ((t (:foreground "#FFFFFF"
        :background "#000000"))))

 '(font-lock-keyword-face
   ((t (:weight bold))))

 '(font-lock-builtin-face
   ((t (:weight bold))))

 '(font-lock-type-face
   ((t ())))
 '(font-lock-constant-face
   ((t ())))
 '(font-lock-variable-name-face
   ((t ())))
 '(font-lock-function-name-face
   ((t ())))
 '(font-lock-function-name-face
   ((t ())))
 '(superscript
   ((t ())))
 '(subscript
   ((t ())))

 '(font-lock-comment-face
   ((t (:foreground "#AAAAAA" :slant italic))))

 '(font-lock-string-face
   ((t (:slant italic))))

 '(cursor
   ((t (:foreground "#000000"
        :background "#FFFFFF"))))

 '(region
   ((t (:foreground "#000000"
        :background "#EEEEEE"))))

 '(fringe
   ((t (:background "#000000"))))
 '(hl-line
   ((t (:background "#222222"))))

 '(git-gutter-fr:added
   ((t (:foreground "#acd8a7"))))
 '(git-gutter-fr:modified
   ((t (:foreground "#f5c77e"))))
 '(git-gutter-fr:deleted
   ((t (:foreground "#ffa590"))))

 '(minibuffer-prompt
   ((t ())))
 '(vertico-current
   ((t (:background "#222222"))))

 '(orderless-match-face-0
   ((t (:weight bold))))
 '(doom-modeline-buffer-modified
   ((t ())))
 '(doom-modeline-vcs-default
   ((t ())))
 '(doom-modeline-evil-normal-state
   ((t ())))
 '(doom-modeline-info
   ((t ())))
 '(doom-modeline-urgent
   ((t (:foreground "#df2c14"))))
 '(doom-modeline-warning
   ((t (:foreground "#dc6601"))))

 ;; vterm ANSI palette -- high-contrast, readable on black, kept in sync
 ;; with st (see st/config.h). Colour is taken from each face's :foreground.
 '(vterm-color-black          ((t (:foreground "#000000"))))
 '(vterm-color-red            ((t (:foreground "#ff5f5f"))))
 '(vterm-color-green          ((t (:foreground "#5fd75f"))))
 '(vterm-color-yellow         ((t (:foreground "#ffd75f"))))
 '(vterm-color-blue           ((t (:foreground "#5f9fff"))))
 '(vterm-color-magenta        ((t (:foreground "#ff5fd7"))))
 '(vterm-color-cyan           ((t (:foreground "#5fd7d7"))))
 '(vterm-color-white          ((t (:foreground "#d0d0d0"))))
 '(vterm-color-bright-black   ((t (:foreground "#6c6c6c"))))
 '(vterm-color-bright-red     ((t (:foreground "#ff8787"))))
 '(vterm-color-bright-green   ((t (:foreground "#87ff87"))))
 '(vterm-color-bright-yellow  ((t (:foreground "#ffff87"))))
 '(vterm-color-bright-blue    ((t (:foreground "#87bfff"))))
 '(vterm-color-bright-magenta ((t (:foreground "#ff87ff"))))
 '(vterm-color-bright-cyan    ((t (:foreground "#87ffff"))))
 '(vterm-color-bright-white   ((t (:foreground "#ffffff"))))
)

(provide-theme 'dark-monochrome)
