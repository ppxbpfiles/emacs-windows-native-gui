;; -*- lexical-binding: t -*-
;; =====================================================================
;; early-init.el — パッケージ初期化・フレーム生成より前の設定
;; =====================================================================

;; ポータブル環境対応：early-init.el 自身の場所から user-emacs-directory を解決する
;; ※ init.el より先に読まれるため、init.el の動的設定はまだ効いていない
(setq user-emacs-directory
      (file-name-directory (or load-file-name buffer-file-name)))

;; 🌟 パッケージ一括読み込み（111個の個別読み込みを0.3秒に短縮）
(setq package-quickstart t)

;; 🌟 起動高速化：起動中のGCとファイル探索オーバーヘッドを一時抑止
(setq gc-cons-threshold (* 128 1024 1024))
(setq gc-cons-percentage 0.6)
(defvar my/saved-file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024))
            (setq gc-cons-percentage 0.1)
            (setq file-name-handler-alist my/saved-file-name-handler-alist)))

;; 🌟 初期フレームを即座に表示
(add-to-list 'initial-frame-alist '(visibility . t))
(add-to-list 'default-frame-alist '(visibility . t))

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
