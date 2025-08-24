(deftheme dark-monochrome "A dark and stylish theme created from scratch.")

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

)

(provide-theme 'dark-monochrome)

