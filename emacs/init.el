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
(setq-default indent-tabs-mode nil)
(setq-default tab-width 2)
(context-menu-mode t)

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
  (evil-collection-init '(magit))
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
  )
)

(use-package magit
  :after general
  :general
  (leader-def 'normal
    "g" '(:ignore t :which-key "(ma)git")
    "gg" 'magit-status
  )
)
(use-package git-gutter
  :ensure t
  :hook (prog-mode . git-gutter-mode)
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
  :config
  (setq projectile-project-search-path '("~/phd" "~/programming" "~/src" "~/config"))
  (setq projectile-indexing-method 'alien)
  (setq projectile-enable-caching 'persistent)
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

; ------ THEME ----------

(add-to-list 'custom-theme-load-path "~/.config/emacs/")
(load-theme 'dark-monochrome t)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes '(default))
 '(package-selected-packages
   '(consult evil evil-collection general git-gutter git-gutter-fringe
             magit projectile)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
