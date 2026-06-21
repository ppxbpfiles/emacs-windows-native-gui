;; -*- lexical-binding: t -*-
;; =====================================================================
;; early-init.el — パッケージ初期化・フレーム生成より前の設定
;; =====================================================================

;; ポータブル環境対応：early-init.el 自身の場所から user-emacs-directory を解決する
;; ※ init.el より先に読まれるため、init.el の動的設定はまだ効いていない
(setq user-emacs-directory
      (file-name-directory (or load-file-name buffer-file-name)))

;; スプラッシュ画面を確実に表示する
;; ※ init.el で設定しても起動判断のタイミングに間に合わないためここで設定する
;;
;; 【現在の状況】
;; obsidian パッケージが起動時に command-line-args にディレクトリパスを
;; 追加するため、Emacs はそれを「開くファイルが指定された」と判断し、
;; スプラッシュ画面の表示をスキップしてしまう。
;; この判定は obsidian パッケージのロードより前に行われるため、
;; ここで inhibit-startup-screen / inhibit-startup-message を nil に
;; しても、obsidian がある現在の構成では実質的に効果がない。
;;
;; 現在スプラッシュ画面を表示させているのは、init.el 側にある
;; my/disable-splash 変数と window-setup-hook によるフォールバック処理
;; （obsidian の影響を受けず、後から強制的に fancy-startup-screen を
;; 呼び出す仕組み）である。
;;
;; 【将来 obsidian パッケージをやめた場合】
;; command-line-args が書き換えられなくなるため、この early-init.el の
;; 設定がそのまま効くようになり、Emacs 標準のスプラッシュ画面表示の
;; 仕組みだけで表示されるようになる。その際は init.el 側の
;; my/disable-splash / window-setup-hook の設定は不要になる
;; （残しておいても害はない）。
(setq inhibit-startup-screen  nil)
(setq inhibit-startup-message nil)

;; banner.png をスプラッシュ画面のロゴとして設定
(let ((banner (expand-file-name "images/banner.png" user-emacs-directory)))
  (when (file-exists-p banner)
    (setq fancy-splash-image banner)))
