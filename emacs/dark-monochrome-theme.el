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

 ;; ---- mail ----
 ;; Nothing in a message may introduce a colour.  message.el is the worst
 ;; offender in the whole config: it paints headers green (header-name),
 ;; OliveDrab1 (subject), chartreuse1 (Cc) and VioletRed1 (From/Date), and
 ;; notmuch draws the crypto banner as black-on-green.  `custom-theme-set-faces'
 ;; *replaces* a face spec rather than merging it, so simply not mentioning
 ;; :background here is what drops those coloured bars; structure is carried by
 ;; weight, slant and underline instead.
 ;;
 ;; Only faces that actually ship a colour are listed.  Plenty of mail faces
 ;; look like candidates but are already neutral (notmuch-search-date,
 ;; notmuch-tree-match-subject-face and friends have a nil defface spec;
 ;; shrface-code reaches `shadow' via org-code) -- overriding those would dim
 ;; text that is currently plain white, which is not the point.
 ;;
 ;; `link' is deliberately untouched (cyan): everything clickable inherits it,
 ;; so links stay the single spot of colour.

 '(message-header-name        ((t (:foreground "#AAAAAA"))))
 '(message-header-subject     ((t (:weight bold))))
 '(message-header-to          ((t (:weight bold))))
 '(message-header-cc          ((t ())))
 '(message-header-newsgroups  ((t ())))
 '(message-header-other       ((t ())))
 '(message-header-xheader     ((t (:foreground "#AAAAAA"))))
 ;; quoted text in a reply buffer: one grey, not LightPink1 then forest green
 ;; then a third colour by nesting depth
 '(message-cited-text-1       ((t (:foreground "#AAAAAA"))))
 '(message-cited-text-2       ((t (:foreground "#AAAAAA"))))
 '(message-cited-text-3       ((t (:foreground "#AAAAAA"))))
 '(message-cited-text-4       ((t (:foreground "#AAAAAA"))))

 ;; the single-line summary bar above each message; #303030 by default, moved
 ;; onto the same grey as hl-line above
 '(notmuch-message-summary-face ((t (:background "#222222" :extend t))))

 ;; crypto banners -- green, orange, red and purple *backgrounds* by default.
 ;; Verification is off (see emacs/init.el), so these only appear after `$'.
 ;; A *bad* signature keeps a real colour: it is the one case where losing the
 ;; visual alarm would be a downgrade rather than a tidy-up.
 '(notmuch-crypto-part-header        ((t (:foreground "#AAAAAA"))))
 '(notmuch-crypto-signature-good     ((t (:foreground "#AAAAAA"))))
 '(notmuch-crypto-signature-good-key ((t (:foreground "#AAAAAA"))))
 '(notmuch-crypto-signature-unknown  ((t (:foreground "#AAAAAA"))))
 '(notmuch-crypto-signature-bad      ((t (:foreground "#ff5f5f" :weight bold))))
 '(notmuch-crypto-decryption         ((t (:foreground "#AAAAAA"))))

 ;; search and tree listings: OliveDrab1 authors, red unread tags, blue flags
 '(notmuch-search-non-matching-authors ((t (:foreground "#AAAAAA"))))
 '(notmuch-search-flagged-face         ((t (:weight bold))))
 '(notmuch-tag-face                    ((t (:foreground "#AAAAAA"))))
 '(notmuch-tag-unread                  ((t (:weight bold))))
 '(notmuch-tag-flagged                 ((t (:weight bold))))
 '(notmuch-tree-match-author-face      ((t ())))
 '(notmuch-tree-match-tag-face         ((t (:foreground "#AAAAAA"))))

 ;; ---- html rendering (shr + shrface), so eww matches too ----
 ;; shr-use-colors is nil in init.el, which drops the *document's* own colours.
 ;; What is left is what emacs adds by itself: because shrface-href-versatile
 ;; is on, shrface hardcodes a different hex per URL scheme -- #39CCCC for
 ;; http, #7FDBFF for https, #8FBCBB for mailto and so on -- so a mail with
 ;; mixed links comes out in three or four blues.  Route them all to `link'.
 ;; shrface-figure is the sneaky one: it reaches LightSkyBlue via org-table.
 '(shrface-href-face        ((t (:inherit link))))
 '(shrface-href-other-face  ((t (:inherit link))))
 '(shrface-href-http-face   ((t (:inherit link))))
 '(shrface-href-https-face  ((t (:inherit link))))
 '(shrface-href-ftp-face    ((t (:inherit link))))
 '(shrface-href-file-face   ((t (:inherit link))))
 '(shrface-href-mailto-face ((t (:inherit link))))
 '(shrface-figure           ((t (:foreground "#AAAAAA"))))
 ;; red and yellow backgrounds respectively; reuse the region grey instead
 '(shr-selected-link ((t (:inherit link :inverse-video t))))
 '(shr-mark          ((t (:inherit region))))

 ;; Not colour, but the reason headings are readable at all: this theme
 ;; flattens the font-lock faces that org-level-N -> outline-N inherit from, so
 ;; an <h1> would otherwise be indistinguishable from body text.  Drop this
 ;; group if you would rather have headings marked only by shrface's bullets.
 '(shrface-h1-face ((t (:weight bold :underline t))))
 '(shrface-h2-face ((t (:weight bold))))
 '(shrface-h3-face ((t (:weight bold :slant italic))))
 '(shrface-h4-face ((t (:slant italic))))
 '(shrface-h5-face ((t (:slant italic))))
 '(shrface-h6-face ((t (:slant italic))))

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
