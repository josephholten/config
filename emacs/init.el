(require 'package)

(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(setq inhibit-startup-message t)
(global-display-line-numbers-mode)
(setq-default indent-tabs-mode nil)
(setq-default tab-width 2)

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

  (setq git-gutter:unchanged-sign " ")
  (custom-set-faces
   '(git-gutter:unchanged ((t (:background nil))))
  )
)

(add-to-list 'custom-theme-load-path "~/.config/emacs/")
(load-theme 'dark-monochrome t)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("4192b8d325bdd1c97612c30d1e2d12c4969c52d1a824d45312191ca65c65dcbf"
     "939cac8dfd0502f66960a1907caf611cde4b9c0cafe684d63cec810701739a92"
     "0c8d0a6e0e74f09aac251e0d1e851bc0fc3db06c4f2443112896536c7894e1de"
     "501f628f27e11ee89cb5dc80e52fce67262cf071f74ed5efca1aeadd10322afe"
     default))
 '(package-selected-packages
   '(evil evil-collection general git-gutter git-gutter-fringe magit)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
