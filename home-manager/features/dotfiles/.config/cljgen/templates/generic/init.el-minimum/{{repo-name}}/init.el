;;; init.el ---                                      -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Naoya Yamashita

;; Author: Naoya Yamashita <conao3@gmail.com>
;; Keywords:

;;; Commentary:

;; emacs --init-directory=~/.debug.emacs.d/{{repo-name}}

;;; Code:

(prog1 "leaf"
  (custom-set-variables
   '(package-archives '(("melpa" . "https://melpa.org/packages/")
                        ("gnu"   . "https://elpa.gnu.org/packages/"))))
  (package-initialize)
  (use-package leaf :ensure t))

(load-file (locate-user-emacs-file "../default.el"))

;; insert your config...


(provide 'init)
;;; init.el ends here
