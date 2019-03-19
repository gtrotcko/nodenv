# nodenv.el

nodenv.el ia an Emacs extension which integrates the editor with [nodenv](https://github.com/nodenv/nodenv "nodenv/nodenv").

Disclaimer
----------
This repository is a fork of the [rbenv.el](https://github.com/senny/rbenv.el
"senny/rbeny.el") project. Please don't ask me anything, I do not even know
Emacs Lisp well enough to create something new. I only heve edited original
rbeny.el and README replacing all mentions of the Ruby and Rbenv with Node and Nodenv.
The main purpose of this repository is my personal using and for me it works well.


Installation
------------

```lisp
(add-to-list 'load-path "~/.emacs.d/site-lisp/")
(require 'nodenv)
(global-nodenv-mode)
```

Usage
-----

* `global-nodenv-mode` activate / deactivate nodenv.el (The current Node version is shown in the modeline)
* `nodenv-use-global` will activate your global Node
* `nodenv-use` allows you to choose what Node version you want to use
* `nodenv-use-corresponding` searches for .node-version and activates
the corresponding Node

Configuration
-------------

**nodenv installation directory**
By default nodenv.el assumes that you installed nodenv into
`~/.nodenv`. If you use a different installation location you can
customize nodenv.el to search in the right place:

```lisp
(setq nodenv-installation-dir "/usr/local/nodenv")
```

*IMPORTANT:*: Currently you need to set this variable before you load nodenv.el

**the modeline**
nodenv.el will show you the active Node in the modeline. If you don't
like this feature you can disable it:

```lisp
(setq nodenv-show-active-node-in-modeline nil)
```

The default modeline representation is the Node version (colored red) in square
brackets. You can change the format by customizing the variable:

```lisp
;; this will remove the colors
(setq nodenv-modeline-function 'nodenv--modeline-plain)
```

You can also define your own function to format the node version as you like.

Credit
-----
This extension is a fork of the [rbenv.el](https://github.com/senny/rbenv.el
"Rbenv on Github") extension. In fact I only have replaced all ruby and rbenv
mentions with node.


