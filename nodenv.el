;;; nodenv.el --- Emacs integration for nodenv

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; M-x global-nodenv-mode toggle the configuration done by nodenv.el

;; M-x nodenv-use-global prepares the current Emacs session to use
;; the global node configured with nodenv.

;; M-x nodenv-use allows you to switch the current session to the node
;; implementation of your choice.

;; helper function used in variable definitions
(defcustom nodenv-installation-dir (or (getenv "NODENV_ROOT")
                                       (concat (getenv "HOME") "/.nodenv/"))
  "The path to the directory where nodenv was installed."
  :group 'nodenv
  :type 'directory)

(defun nodenv--expand-path (&rest segments)
  (let ((path (mapconcat 'identity segments "/"))
        (installation-dir (replace-regexp-in-string "/$" "" nodenv-installation-dir)))
    (expand-file-name (concat installation-dir "/" path))))

(defcustom nodenv-interactive-completion-function
  (if ido-mode 'ido-completing-read 'completing-read)
  "The function which is used by nodenv.el to interactivly complete user input"
  :group 'nodenv
  :type 'function)

(defcustom nodenv-show-active-node-in-modeline t
  "Toggles wether nodenv-mode shows the active node in the modeline."
  :group 'nodenv
  :type 'boolean)

(defcustom nodenv-modeline-function 'nodenv--modeline-with-face
  "Function to specify the nodenv representation in the modeline."
  :group 'nodenv
  :type 'function)

(defvar nodenv-executable (nodenv--expand-path "bin" "nodenv")
  "path to the nodenv executable")

(defvar nodenv-node-shim (nodenv--expand-path "shims" "node")
  "path to the node shim executable")

(defvar nodenv-global-version-file (nodenv--expand-path "version")
  "path to the global version configuration file of nodenv")

(defvar nodenv-version-environment-variable "NODENV_VERSION"
  "name of the environment variable to configure the nodenv version")

(defvar nodenv-binary-paths (list (cons 'shims-path (nodenv--expand-path "shims"))
                                  (cons 'bin-path (nodenv--expand-path "bin")))
  "these are added to PATH and exec-path when nodenv is setup")

(defface nodenv-active-node-face
    '((t (:weight bold :foreground "Red")))
  "The face used to highlight the current node on the modeline.")

(defvar nodenv--initialized nil
  "indicates if the current Emacs session has been configured to use nodenv")

(defvar nodenv--modestring nil
  "text nodenv-mode will display in the modeline.")
(put 'nodenv--modestring 'risky-local-variable t)

;;;###autoload
(defun nodenv-use-global ()
  "activate nodenv global node"
  (interactive)
  (nodenv-use (nodenv--global-node-version)))

;;;###autoload
(defun nodenv-use-corresponding ()
  "search for .node-version and activate the corresponding node"
  (interactive)
  (let ((version-file-path (or (nodenv--locate-file ".node-version")
                               (nodenv--locate-file ".nodenv-version"))))
    (if version-file-path (nodenv-use (nodenv--read-version-from-file version-file-path))
      (message "[nodenv] could not locate .node-version or .nodenv-version"))))

;;;###autoload
(defun nodenv-use (node-version)
  "choose what node you want to activate"
  (interactive
   (let ((picked-node (nodenv--completing-read "Node version: " (nodenv/list))))
     (list picked-node)))
  (nodenv--activate node-version)
  (message (concat "[nodenv] using " node-version)))

(defun nodenv/list ()
  (append '("system")
          (split-string (nodenv--call-process "versions" "--bare") "\n")))

(defun nodenv--setup ()
  (when (not nodenv--initialized)
    (dolist (path-config nodenv-binary-paths)
      (let ((bin-path (cdr path-config)))
        (setenv "PATH" (concat bin-path ":" (getenv "PATH")))
        (add-to-list 'exec-path bin-path)))
    (setq eshell-path-env (getenv "PATH"))
    (setq nodenv--initialized t)
    (nodenv--update-mode-line)))

(defun nodenv--teardown ()
  (when nodenv--initialized
    (dolist (path-config nodenv-binary-paths)
      (let ((bin-path (cdr path-config)))
        (setenv "PATH" (replace-regexp-in-string (regexp-quote (concat bin-path ":")) "" (getenv "PATH")))
        (setq exec-path (remove bin-path exec-path))))
    (setq eshell-path-env (getenv "PATH"))
    (setq nodenv--initialized nil)))

(defun nodenv--activate (node-version)
  (setenv nodenv-version-environment-variable node-version)
  (nodenv--update-mode-line))

(defun nodenv--completing-read (prompt options)
  (funcall nodenv-interactive-completion-function prompt options))

(defun nodenv--global-node-version ()
  (if (file-exists-p nodenv-global-version-file)
      (nodenv--read-version-from-file nodenv-global-version-file)
    "system"))

(defun nodenv--read-version-from-file (path)
  (with-temp-buffer
    (insert-file-contents path)
    (nodenv--replace-trailing-whitespace (buffer-substring-no-properties (point-min) (point-max)))))

(defun nodenv--locate-file (file-name)
  "searches the directory tree for an given file. Returns nil if the file was not found."
  (let ((directory (locate-dominating-file default-directory file-name)))
    (when directory (concat directory file-name))))

(defun nodenv--call-process (&rest args)
  (with-temp-buffer
    (let* ((success (apply 'call-process nodenv-executable nil t nil
                           (delete nil args)))
           (raw-output (buffer-substring-no-properties
                        (point-min) (point-max)))
           (output (nodenv--replace-trailing-whitespace raw-output)))
      (if (= 0 success)
          output
        (message output)))))

(defun nodenv--replace-trailing-whitespace (text)
  (replace-regexp-in-string "[[:space:]\n]+\\'" "" text))

(defun nodenv--update-mode-line ()
  (setq nodenv--modestring (funcall nodenv-modeline-function
                                    (nodenv--active-node-version))))

(defun nodenv--modeline-with-face (current-node)
  (append '(" [")
          (list (propertize current-node 'face 'nodenv-active-node-face))
          '("]")))

(defun nodenv--modeline-plain (current-node)
  (list " [" current-node "]"))

(defun nodenv--active-node-version ()
  (or (getenv nodenv-version-environment-variable) (nodenv--global-node-version)))

;;;###autoload
(define-minor-mode global-nodenv-mode
    "use nodenv to configure the node version used by your Emacs."
  :global t
  (if global-nodenv-mode
      (progn
        (when nodenv-show-active-node-in-modeline
          (unless (memq 'nodenv--modestring global-mode-string)
            (setq global-mode-string (append (or global-mode-string '(""))
                                             '(nodenv--modestring)))))
        (nodenv--setup))
    (setq global-mode-string (delq 'nodenv--modestring global-mode-string))
    (nodenv--teardown)))

(provide 'nodenv)

;;; nodenv.el ends here
