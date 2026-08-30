;;; init.el --- Joseph's emacs config -*- lexical-binding: t; -*-

;; The cookie above must stay on line 1: without it emacs 30 loads this file
;; with dynamic binding, and any `lambda' here that refers to a surrounding
;; variable is not a closure -- the variable is simply void when the lambda
;; eventually runs.  Nothing in this file depended on dynamic scope when the
;; cookie was added.

(require 'package)

(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(setq inhibit-startup-message t)
(global-display-line-numbers-mode)
(global-hl-line-mode 1)
(setq make-backup-files nil)
(setq-default indent-tabs-mode nil)
(setq-default tab-width 2)
(setq js-indent-level 2)
(setq python-indent-offset 2)
(context-menu-mode t)
(setq tex-fontify-script nil)
(setq-default show-trailing-whitespace t)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

; ------------- FUNCS ------------------
(defun load-init-file ()
  (interactive)
  (load-file user-init-file)
  (message "Configuration reloaded from %s" user-init-file)
)
(defun tex-forward-search ()
  "Forward search from Emacs to Zathura using SyncTeX."
  (interactive)
  (let* ((tex-file (buffer-file-name))
         (pdf-file (replace-regexp-in-string "\\.tex$" ".pdf" tex-file))
         (line-number (line-number-at-pos)))
    (call-process "zathura" nil 0 nil
                  "--synctex-forward"
                  (format "%d:0:%s" line-number tex-file)
                  pdf-file)))

(defun consult-projectile-ripgrep ()
  "Search in current project with consult-ripgrep."
  (interactive)
  (consult-ripgrep (projectile-project-root)))

(defvar my/display-line-numbers-exempt-modes '(vterm-mode)
  "Major modes `global-display-line-numbers-mode' must never turn on in.")

(defun my/display-line-numbers--exempt-p ()
  "Return nil in a buffer that should never get line numbers.
`:before-while' advice on `display-line-numbers--turn-on', which is
the function the *global* mode calls per buffer -- returning nil
stops it there.

A `vterm-mode' hook doing (display-line-numbers-mode -1) cannot do
this job: `SPC h r' re-evaluates `(global-display-line-numbers-mode)'
near the top of this file, and calling a globalized minor mode with
a nil argument *enables* it, which re-runs its turn-on function in
every existing buffer.  The mode hook ran when the terminal was
created and never runs again, so every open vterm gets numbers back.
Advising the seam covers existing and new buffers both, and leaves
`M-x display-line-numbers-mode' working by hand.

`advice-add' dedupes on the function symbol, so re-running this on
reload does not stack copies."
  (not (derived-mode-p my/display-line-numbers-exempt-modes)))

(advice-add 'display-line-numbers--turn-on :before-while
            #'my/display-line-numbers--exempt-p)

;; Escape hatch for the html mail shr mangles (CSS layout, heavy tables), and
;; the only way to see remote images, which are blocked inline. Nothing opens
;; on its own -- this only puts a link above the rendered part.
(defun notmuch-show-html-open-in-browser (msg part crypto)
  "Write the html of PART in MSG to a temp file and open it in the browser."
  (let ((file (expand-file-name "message.html"
                                (make-temp-file "notmuch-html-" t))))
    (with-temp-file file
      (insert (notmuch-get-bodypart-text msg part crypto)))
    (browse-url-of-file file)))

(defun notmuch-show-insert-html-browser-link (msg part)
  "Insert a clickable link that opens this html PART in the browser.
Advice on `notmuch-show--insert-part-text/html-shr', which takes
the same two arguments.  A *text* button, not an overlay one, so
the marker property below survives however notmuch moves the part
around, and TAB (`notmuch-show-next-button') lands on it."
  (insert-text-button "[open in browser]"
                      'face 'link
                      'follow-link t
                      'help-echo "Render this html part in the external browser"
                      ;; stashed on the button rather than closed over.  A
                      ;; closure would work now that this file is lexically
                      ;; bound, but the button outlives this call and notmuch
                      ;; moves the part around; properties travel with the text,
                      ;; and they stay inspectable with `describe-text-properties'
                      'notmuch-html-msg msg
                      'notmuch-html-part part
                      'notmuch-html-crypto notmuch-show-process-crypto
                      'action #'notmuch-show-html-browser-link-action)
  (insert "\n"))

(defun notmuch-show-html-browser-link-action (button)
  "Open the html BUTTON was made for in the external browser."
  (notmuch-show-html-open-in-browser
   (button-get button 'notmuch-html-msg)
   (button-get button 'notmuch-html-part)
   (button-get button 'notmuch-html-crypto)))

(defun notmuch-show--find-html-part (parts)
  "Return the first text/html part in PARTS, descending into multiparts."
  (catch 'found
    (dolist (part parts)
      (when (equal (downcase (or (plist-get part :content-type) "")) "text/html")
        (throw 'found part))
      (let ((sub (plist-get part :content)))
        (when (consp sub)
          (let ((hit (notmuch-show--find-html-part sub)))
            (when hit (throw 'found hit))))))
    nil))

(defun notmuch-show-open-html-in-browser ()
  "Open the html of the message at point in the browser, from anywhere in it.
The link only exists where the html part got rendered; this does
not need point to be on it."
  (interactive)
  (let* ((msg (notmuch-show-get-message-properties))
         (part (notmuch-show--find-html-part (plist-get msg :body))))
    (unless part
      (user-error "This message has no text/html part"))
    (notmuch-show-html-open-in-browser msg part notmuch-show-process-crypto)))

;; Address book. notmuch-address.el already harvests addresses for TAB
;; completion in a To: header, but only in one direction (`sent' OR
;; `received', see `notmuch-address-internal-completion') and one address at a
;; time. This builds the union, people I have written to first -- they are the
;; ones I actually mean -- then people who have written to me.
(defvar notmuch-address-book--cache nil
  "Cons of (IDENTITIES . ADDRESSES) from the last address book build.
Keyed on the identity list because every candidate is derived from
it: adding an address to other_email in mail/notmuch-config has to
invalidate this.  Reloading init.el does NOT clear it -- `defvar'
leaves an already-bound variable alone -- which is exactly why the
key is stored rather than trusting a reload to rebuild.")

(defun notmuch-address-book--query (direction)
  "Addresses from `notmuch address'.
DIRECTION is `sent' (recipients of mail I sent) or `received'
\(senders of mail I got).  --deduplicate=address collapses the
same address appearing under several display names."
  (let ((sent (eq direction 'sent)))
    (process-lines notmuch-command "address"
                   (if sent "--output=recipients" "--output=sender")
                   "--deduplicate=address"
                   (mapconcat (lambda (addr)
                                (concat (if sent "from:" "to:") addr))
                              (notmuch-user-emails) " or "))))

(defun notmuch-address-book (&optional refresh)
  "Every address notmuch knows, sent-to first, then received-from.
Order matters: the completion table below preserves it.  Cached,
since the sent query walks the whole index (~1s).  Rebuilt when
REFRESH is non-nil, or when my set of addresses has changed."
  (let ((identities (notmuch-user-emails)))
    (unless (and (null refresh)
                 (equal identities (car notmuch-address-book--cache)))
      (let ((seen (make-hash-table :test 'equal))
            (result nil))
        ;; my own addresses are never useful candidates
        (dolist (mine identities)
          (puthash (downcase mine) t seen))
        (dolist (entry (append (notmuch-address-book--query 'sent)
                               (notmuch-address-book--query 'received)))
          ;; dedupe on the address alone, so "Jo <a@b>" and "a@b" are one entry
          (let ((addr (downcase (or (cadr (mail-extract-address-components entry))
                                    entry))))
            (unless (gethash addr seen)
              (puthash addr t seen)
              (push entry result))))
        (setq notmuch-address-book--cache (cons identities (nreverse result))))))
  (cdr notmuch-address-book--cache))

(defun notmuch-address-book--table (candidates)
  "Completion table over CANDIDATES that keeps their order.
Without the sort-function overrides vertico reorders by history
and length, which loses the sent-before-received ranking."
  (lambda (string pred action)
    (if (eq action 'metadata)
        '(metadata (category . email)
                   (display-sort-function . identity)
                   (cycle-sort-function . identity))
      (complete-with-action action candidates string pred))))

;; orderless comes from the package below; declared here so that let-binding it
;; in the two commands is a dynamic binding orderless actually sees.
(defvar orderless-affix-dispatch-alist)

(defun notmuch-address-book--dispatch-alist ()
  "`orderless-affix-dispatch-alist' minus the comma entry.
A comma is orderless' *initialism* dispatcher, so typing a display
name the way Exchange writes it -- \"Salatovic, Stjepan\" -- asks
orderless to match the initials S-a-l-a-... and finds nothing.
Half the KIT addresses are in that form.  Only that one dispatcher
is dropped, so ~flex, !not and =literal keep working."
  (and (boundp 'orderless-affix-dispatch-alist)
       (seq-remove (lambda (entry) (eq (car entry) ?,))
                   orderless-affix-dispatch-alist)))

(defun notmuch-address-book-expand-name ()
  "Complete the address before point from `notmuch-address-book'.
Replaces `notmuch-address-expand-name' in `message-completion-alist'
\(see the notmuch block below).  notmuch's own version completes
from `notmuch-address-completions', which is harvested in one
direction only -- `notmuch-address-internal-completion' is either
sent or received, never both -- and which it pre-filters by what
you have already typed, so it only ever offers a subset of what
`SPC m a' offers.  This shares one address book with that command."
  (let* ((end (point))
         ;; A header holds several addresses, so complete only the one after
         ;; the last comma -- or after the header name, on the first line.
         ;; This is also why a display-name comma cannot be typed *here*: in
         ;; a header the comma is the recipient separator.  Type "Salatovic"
         ;; and pick from the minibuffer, where the comma is fine again.
         (beg (save-excursion
                (re-search-backward "\\(\\`\\|[\n:,]\\)[ \t]*")
                (goto-char (match-end 0))
                (point)))
         (orig (buffer-substring-no-properties beg end))
         (completion-ignore-case t)
         (orderless-affix-dispatch-alist (notmuch-address-book--dispatch-alist))
         (chosen (completing-read
                  "Address: "
                  (notmuch-address-book--table (notmuch-address-book))
                  nil nil orig 'notmuch-address-history)))
    (unless (string-empty-p chosen)
      (delete-region beg end)
      (insert chosen))))

(defun notmuch-compose-to (&optional refresh)
  "Pick recipients from the address book, then compose to all of them.
Keeps asking until you answer empty.  Addresses not in the book
can just be typed.  With a prefix arg REFRESH rebuilds the book
first -- it is otherwise built once per emacs session."
  (interactive "P")
  ;; Nothing here is autoloaded -- `notmuch-address-book' calls
  ;; `notmuch-user-emails', and the sender prompt below needs notmuch-mua --
  ;; so this command would fail if it were the first mail thing done in a
  ;; session.  `SPC m m' or `SPC m s' happened to load notmuch first.
  (require 'notmuch-mua)
  (let ((book (notmuch-address-book refresh))
        (orderless-affix-dispatch-alist (notmuch-address-book--dispatch-alist))
        (picked nil))
    (while (let ((pick (completing-read
                        (format "To (%d picked, empty to finish): "
                                (length picked))
                        (notmuch-address-book--table
                         (seq-remove (lambda (c) (member c picked)) book))
                        nil nil)))
             ;; nil ends the loop, so an empty answer is the exit
             (unless (string-empty-p pick)
               (push pick picked))))
    (if (null picked)
        (message "No recipients picked")
      ;; `notmuch-always-prompt-for-sender' is read by `notmuch-mua-new-mail'
      ;; and by forwarding, not by `notmuch-mua-mail' itself, so honour it
      ;; here by hand.  Asked after the recipients, so answering the To
      ;; prompt empty aborts without a second question.
      (notmuch-mua-mail (mapconcat #'identity (nreverse picked) ", ")
                        nil
                        (and notmuch-always-prompt-for-sender
                             (list (cons 'From (notmuch-mua-prompt-for-sender))))))))

(defun notmuch-mua-new-reply--always-prompt (orig query-string
                                                  &optional prompt-for-sender
                                                  reply-all duplicate)
  "Make `notmuch-always-prompt-for-sender' cover replies too.
Upstream reads that variable in `notmuch-mua-new-mail' and when
forwarding, but `notmuch-mua-new-reply' looks only at its own
PROMPT-FOR-SENDER, i.e. at a `C-u' prefix.  Reply is where the
choice matters most -- answering a KIT thread should go out from
the KIT address -- and From: decides both which msmtp account
sends and which Sent folder `notmuch-fcc-dirs' files the copy in.
ORIG is `notmuch-mua-new-reply'; QUERY-STRING, REPLY-ALL and
DUPLICATE are passed through untouched."
  (funcall orig query-string
           (or prompt-for-sender notmuch-always-prompt-for-sender)
           reply-all duplicate))

;; Per-account drafts. `notmuch-draft-folder' is a plain string, not an alist
;; like `notmuch-fcc-dirs', so upstream postpones both accounts into one
;; folder -- and its default, "drafts", exists under neither. That default is
;; not merely wrong but actively bad: `notmuch-draft-save' passes create=t, so
;; the first `C-c C-p' would create ~/mail/drafts at the *database root*, one
;; level above both account maildirs, where no mbsync channel reaches it. The
;; draft would then live only on this machine, invisible to OWA and to any
;; other client, with nothing to indicate it had not been saved properly.
;;
;; Same From-regexp dispatch as `notmuch-fcc-dirs', same ordering rule: first
;; hit wins, so the "" catch-all stays last. Unlike `notmuch-fcc-dirs' the
;; folder needs no quoting -- it is handed to
;; `notmuch-maildir-notmuch-insert-current-buffer' as its own argument and
;; never goes through `split-string-and-unquote' -- so a name with a space
;; would be fine here, and "Entwürfe" must NOT be quoted.
(defvar notmuch-draft-dirs
  '(("kit\\.edu" . "kit/Entwürfe")
    (""          . "holten/Drafts"))
  "Alist of (REGEXP . FOLDER), matched against the From header.
Per-account replacement for `notmuch-draft-folder', which holds a
single folder for all identities.  FOLDER is relative to the
notmuch database root, i.e. it starts with the account directory.")

(defun notmuch-draft-save--per-account (orig &rest args)
  "Bind `notmuch-draft-folder' from `notmuch-draft-dirs' around ORIG.
ORIG is `notmuch-draft-save', which reads the folder as a dynamic
variable at the point of the `notmuch insert' call, so let-binding
it here is enough -- no need to touch the temporary message buffer
it saves from.  `notmuch-draft-postpone' routes through the same
function, so C-c C-p is covered too.  ARGS is passed through.
Falls back to the upstream value if nothing matches, which cannot
happen while the alist ends in a \"\" catch-all."
  (let* ((from (or (message-field-value "From") ""))
         (notmuch-draft-folder
          (or (seq-some (pcase-lambda (`(,regexp . ,folder))
                          (and (string-match-p regexp from) folder))
                        notmuch-draft-dirs)
              notmuch-draft-folder)))
    (apply orig args)))

; ------------ PACKAGES ----------------
(use-package evil
  :ensure t
  :init (setq evil-want-keybinding nil)
  :config
  (evil-mode 1)
)
(use-package evil-collection
  :after evil
  :ensure t
  :config
  (evil-collection-init '(magit dired notmuch))
)
(use-package which-key
  :ensure t
  :config
  (which-key-mode)
)
(use-package general
  :ensure t
  :config
  (general-evil-setup)
  (general-create-definer leader-def
    :prefix "SPC"
  )
  (leader-def 'normal
    "h" '(:ignore t :which-key "help - emacs config")
    "hr" 'load-init-file
    "hc" 'describe-char

    "w" '(:ignore t :which-key "window")
    "wq" 'evil-quit
    "ws" 'evil-window-split
    "wv" 'evil-window-vsplit
    "wl" 'evil-window-right
    "wh" 'evil-window-left
    "wk" 'evil-window-up
    "wj" 'evil-window-down

    "tv" 'tex-forward-search
  )
)
(use-package dired
  :ensure nil
  :general
  (general-def 'normal 'dired-mode-map
    "SPC" nil
  )
)

(use-package magit
  :after general
  :general
  (leader-def 'normal
    "g" '(:ignore t :which-key "(ma)git")
    "gg" 'magit-status
    "gi" 'magit-init
  )
)
(use-package git-gutter
  :ensure t
  :config
  (global-git-gutter-mode 1)
)
(use-package git-gutter-fringe
  :after git-gutter
  :ensure t
  :config
  (define-fringe-bitmap 'git-gutter-fr:added    [224] nil nil '(center repeated))
  (define-fringe-bitmap 'git-gutter-fr:modified [224] nil nil '(center repeated))
  (define-fringe-bitmap 'git-gutter-fr:deleted  [255 255] nil nil 'bottom)
)

(use-package projectile
  :ensure t
  :diminish projectile-mode
  :init
  (projectile-mode 1)
  :general
  (leader-def 'normal
    "p" 'projectile-command-map
  )
  (:keymaps 'projectile-command-map
    "s" 'consult-projectile-ripgrep
  )
  :config
  (setq projectile-project-search-path '("~/phd" "~/programming" "~/src" "~/config" "~/phd/HyperHDG"))
  (setq projectile-indexing-method 'alien)
  (setq projectile-enable-caching 'persistent)
  (setq projectile-switch-project-action 'projectile-dired)
)

(use-package savehist
  :ensure t
  :init
  (savehist-mode)
)
(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles partial-completion))))
)
(use-package vertico
  :ensure t
  :init
  (vertico-mode)
)
(use-package consult
  :after general
  :ensure t
  :general
  (leader-def 'normal
    "<" 'consult-buffer
  )
)

(use-package vterm
  :ensure t
  :custom
  (vterm-kill-buffer-on-exit t)
  :hook
  (vterm-mode . (lambda () (setq show-trailing-whitespace nil)))
  ;; No display-line-numbers hook here -- `vterm-mode' is in
  ;; `my/display-line-numbers-exempt-modes' instead, which also survives a
  ;; config reload. See `my/display-line-numbers--exempt-p'.
  (vterm-mode . (lambda ()
                  (add-hook 'evil-insert-state-entry-hook
                            (lambda () (vterm-goto-char (point)))
                            nil t)))
  :general
  (general-def 'normal 'vterm-mode-map
    "p" (lambda () (interactive)
          (unless (eolp) (forward-char))
          (vterm-yank))
    "P" 'vterm-yank)
  (general-def 'insert 'vterm-mode-map
    "C-v" 'vterm-yank-primary
    "C-u" 'vterm--self-insert
    "C-o" 'vterm--self-insert
    "C-y" 'vterm--self-insert
    "C-d" 'vterm--self-insert
    "C-r" 'vterm--self-insert
    "C-b" 'vterm--self-insert
  )
  :config
  ;; Keep the view where you put it when you scroll up into the scrollback.
  ;; Frequent terminal output (e.g. Claude Code's progress spinner) repaints
  ;; every `vterm-timer-delay' seconds, and each repaint moves point/window to
  ;; the terminal cursor -- which makes it impossible to scroll up and read
  ;; while a program is still producing output.  We freeze a window only when
  ;; its point sits ABOVE the terminal cursor (i.e. you've scrolled up into the
  ;; scrollback).  A window at or below the cursor -- where you are while typing
  ;; -- keeps following output, so the cursor still tracks your input.
  (defvar-local my/vterm--cursor-anchor nil
    "Buffer position of the terminal cursor right after the last redraw.")
  (defun my/vterm--keep-scroll-position (orig-fn buffer)
    "Around advice for `vterm--delayed-redraw' that preserves scrollback view."
    (let (saved)
      (when (buffer-live-p buffer)
        (with-current-buffer buffer
          (let ((anchor my/vterm--cursor-anchor))
            ;; Only act on a sane anchor; after a screen clear the buffer can
            ;; shrink below it, in which case we just let everything follow.
            (when (and anchor (<= anchor (point-max)))
              (dolist (win (get-buffer-window-list buffer nil t))
                (when (< (window-point win) anchor)
                  (push (list win (window-start win) (window-point win))
                        saved)))))))
      (funcall orig-fn buffer)
      ;; Record where the cursor landed *before* restoring any frozen windows,
      ;; so the anchor tracks the terminal cursor rather than a scrolled view.
      (when (buffer-live-p buffer)
        (with-current-buffer buffer
          (setq my/vterm--cursor-anchor (point))))
      (dolist (entry saved)
        (let ((win (nth 0 entry))
              (start (nth 1 entry))
              (wpoint (nth 2 entry)))
          (when (window-live-p win)
            (set-window-start win start t)
            (set-window-point win wpoint))))))
  (advice-add 'vterm--delayed-redraw :around #'my/vterm--keep-scroll-position)
)

(use-package multi-vterm
  :ensure t
  :after vterm
  :general
  (leader-def 'normal
    "t t" 'multi-vterm
    "t p" 'multi-vterm-project
    "t d" 'multi-vterm-dedicated-toggle
    "t r" 'multi-vterm-rename-buffer
  )
  (general-def 'normal 'vterm-mode-map
    "]t" 'multi-vterm-next
    "[t" 'multi-vterm-prev
  )
  ("<f12>" 'multi-vterm-dedicated-toggle)
)

;; mail. :ensure nil -- Arch's notmuch package ships the elisp into
;; /usr/share/emacs/site-lisp (already on load-path). Do NOT take this from
;; MELPA: notmuch-emacs must match the notmuch CLI version, and pacman keeps
;; them in lockstep. See mail/README.md for the mbsync side.
(use-package notmuch
  :ensure nil
  :commands notmuch
  :general
  (leader-def 'normal
    "m" '(:ignore t :which-key "mail")
    "mm" 'notmuch
    "ms" 'notmuch-search
    "mc" 'notmuch-mua-new-mail
    "ma" 'notmuch-compose-to
    "mu" 'notmuch-poll-and-refresh-this-buffer
  )
  ;; the global show-trailing-whitespace makes mail unreadable -- other people's
  ;; mailers leave trailing space on nearly every line, and it is not ours to fix
  :hook
  ((notmuch-hello-mode notmuch-search-mode notmuch-show-mode notmuch-tree-mode)
   . (lambda () (setq show-trailing-whitespace nil)))
  :config
  ;; Send via msmtp (mail/msmtprc), not emacs' own smtpmail -- one credential
  ;; path for both directions, and msmtp handles the pass lookup.
  (setq send-mail-function 'sendmail-send-it
        message-send-mail-function 'message-send-mail-with-sendmail
        sendmail-program (executable-find "msmtp")
        message-sendmail-envelope-from 'header
        ;; Ask which address to send as on every compose, instead of silently
        ;; using primary_email. The From header is what picks *both* the msmtp
        ;; account and the Fcc target below, so it is a per-message decision,
        ;; not a default. Candidates come from primary_email + other_email in
        ;; mail/notmuch-config.
        notmuch-always-prompt-for-sender t
        ;; drop a copy in the local Sent maildir; mbsync pushes it up.
        ;; An alist because there are two accounts: each car is a regexp
        ;; matched against the From header, first hit wins, so the "" catch-all
        ;; must stay last. Filing into the wrong account's Sent would upload
        ;; the message to the wrong server on the next sync.
        ;; KIT is a German-locale Exchange server: its real Sent folder is
        ;; "Gesendete Elemente" (there is also a stale "Sent" from some earlier
        ;; client). Filing into the wrong one hides sent mail from Outlook/OWA.
        ;;
        ;; The embedded double quotes are REQUIRED, not decoration. The cdr
        ;; becomes the whole Fcc header, and `notmuch-maildir-fcc-with-notmuch-insert'
        ;; runs it through `split-string-and-unquote' to peel off trailing
        ;; "+tag"/"-tag" arguments -- so an unquoted name splits at the space and
        ;; sending fails with `notmuch insert --folder=kit/Gesendete Elemente'
        ;; => "Error: unexpected query string: Elemente". Only double quotes
        ;; survive that split; a backslash-escaped space does not.
        notmuch-fcc-dirs '(("kit\\.edu" . "\"kit/Gesendete Elemente\"")
                           (""          . "holten/Sent")))
  ;; Do NOT verify signatures on open. 469 messages here are S/MIME signed
  ;; (mostly KIT lists) and none are PGP, so `notmuch show --verify' means
  ;; gpgsm, and gpgsm cannot validate a chain whose root it does not trust --
  ;; it stops and asks, via pinentry, whether to *ultimately trust* that root,
  ;; writing the answer to ~/.gnupg/trustlist.txt. Answering that per sender is
  ;; not a decision worth making just to read mail, and saying yes grants the CA
  ;; authority over every future signature. Off by default; `$'
  ;; (`notmuch-show-toggle-process-crypto') verifies the message at point when
  ;; it actually matters. Also removes the colored crypto banner from every mail.
  (setq notmuch-crypto-process-mime nil)
  ;; TAB in a To:/Cc:/Bcc:/... header completes from the same address book as
  ;; `SPC m a', instead of notmuch's one-directional pre-filtered harvest.
  ;;
  ;; Overriding the function rather than editing `message-completion-alist':
  ;; `notmuch-address-setup' runs in the `notmuch-message-mode' body, so it
  ;; re-registers itself for *every* compose buffer, long after this :config.
  ;; It does so with `cl-pushnew ... :test #'equal' on the whole (REGEXP . FN)
  ;; cons, which does not match an entry carrying a different FN -- so it would
  ;; happily push its own pair in front of mine and win. Taking the function
  ;; instead also fixes the "Resend to:" prompt, the other caller, and
  ;; `advice-add' dedupes on the symbol so `SPC h r' cannot stack copies.
  ;;
  ;; This is also what retires `notmuch-address-save-filename': the on-disk
  ;; harvest cache existed for `notmuch-address-options', and that is now
  ;; unreachable. `notmuch-address-book' does its own caching.
  (advice-add 'notmuch-address-expand-name :override
              #'notmuch-address-book-expand-name)
  ;; `c r' / `c R' ask for the sender as well -- see the defun for why this
  ;; needs an advice rather than just the setq above.
  (advice-add 'notmuch-mua-new-reply :around
              #'notmuch-mua-new-reply--always-prompt)
  ;; `C-c C-p' (postpone) files the draft in the right account's folder --
  ;; see the defun for why upstream's single `notmuch-draft-folder' is not
  ;; just wrong here but writes outside the synced maildirs entirely.
  (advice-add 'notmuch-draft-save :around
              #'notmuch-draft-save--per-account)
  ;; `notmuch new` on demand, so SPC m u refreshes the index from within emacs.
  ;; It does not run mbsync -- fetch still happens outside (see mail/README.md).
  ;; newest first. Must be setq-default: notmuch makes this buffer-local, and
  ;; `notmuch-search' reads its default-value, so a plain setq has no effect.
  (setq-default notmuch-search-oldest-first nil)
  ;; HTML mail is rendered by shr (emacs 30 is built without xwidgets, so no
  ;; embedded webkit). These are global -- eww gets them too.
  (setq shr-use-colors nil        ; ignore the mail's own fg/bg, which is what
                                  ; makes html mail unreadable on a dark theme
        shr-max-width 90          ; 120 is too wide to read comfortably
        shr-discard-aria-hidden t ; drop screen-reader-only text
        shr-image-animate nil
        shr-cookie-policy nil)    ; never send cookies for mail images
  ;; notmuch-show-text/html-blocked-images defaults to "." -- every remote
  ;; image is blocked, i.e. no tracking pixels. The [open in browser] link is
  ;; how you see them when a mail actually needs it.
  (advice-add 'notmuch-show--insert-part-text/html-shr :before
              #'notmuch-show-insert-html-browser-link)
  ;; RET and mouse on the link work by themselves -- a keymap text property
  ;; outranks evil's state maps, which is also why shr's own links work. TAB
  ;; (`notmuch-show-next-button') walks to it; `&' skips the walk.
  (general-define-key
   :states 'normal :keymaps 'notmuch-show-mode-map
   "&" 'notmuch-show-open-html-in-browser)
  (setq notmuch-show-logo nil
        notmuch-saved-searches
        '((:name "inbox"  :key "i" :query "tag:inbox")
          (:name "unread" :key "u" :query "tag:unread")
          (:name "48h"    :key "t" :query "date:2d..")
          ;; folder: is an exact match on the whole path relative to the
          ;; database root, not a suffix match -- plain "folder:Sent" matched
          ;; nothing. Keep in sync with `notmuch-fcc-dirs' above.
          (:name "sent"   :key "s"
                 :query "folder:holten/Sent or folder:\"kit/Gesendete Elemente\"")
          (:name "all"    :key "a" :query "*")))
)

;; typography on top of shr: real heading faces, indentation, styled code and
;; links. :after notmuch so it loads before any mail gets rendered, and never
;; at startup. shrface-basic/-trial install handlers into the global
;; shr-external-rendering-functions, so eww benefits too.
;; (Not enabling shrface-mode: its outline folding fights notmuch-show's own
;; message folding. It only adds navigation/imenu, not the rendering.)
(use-package shrface
  :ensure t
  :after notmuch
  :config
  (shrface-basic)
  (shrface-trial)
  (setq shrface-href-versatile t)
)

(use-package doom-modeline
  :ensure t
  :init (doom-modeline-mode 1)
  :config
  (setq doom-modeline-buffer-file-name-style 'file-name)
  (setq doom-modeline-icon nil)
)

(use-package cmake-mode
  :ensure t)

(use-package julia-mode
  :ensure t
  :pin nongnu)

(use-package ein
  :ensure t)

; ------ THEME ----------

(add-to-list 'custom-theme-load-path "~/.config/emacs/")
(load-theme 'dark-monochrome t)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes '(default))
 '(package-selected-packages nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

