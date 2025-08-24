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
)

(provide-theme 'dark-monochrome)

