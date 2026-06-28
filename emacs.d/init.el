;; -*- lexical-binding: t -*-
;; =====================================================================
;; init.el — Windows Emacs 個人設定
;; =====================================================================

;; 🌟 ネットワークエラー対策 (unknown address family)
;; IPv6 を無効にして IPv4 を優先するように設定します
(setq network-lookup-address-preference 'ipv4)

;; ポータブル環境対応：user-emacs-directory を init.el の場所から動的に設定する
;; これにより USB 等で持ち運んでも絶対パスに依存しない
(setq user-emacs-directory
      (file-name-directory (or load-file-name buffer-file-name)))

;; 🌟 ポータブル環境用：.authinfo をホームディレクトリではなく .emacs.d の中に配置する設定
(setq auth-sources
      (list (expand-file-name ".authinfo" user-emacs-directory)
            (expand-file-name ".authinfo.gpg" user-emacs-directory)))

;; M-x customize の設定を専用ファイルに分離（init.el への自動書き込みを防止）
;; これにより custom-set-variables / custom-set-faces は custom.el に書かれる
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file nil t))


;; =====================================================================
;; 1. 起動・基本動作
;; =====================================================================

;; スクラッチバッファのメッセージを非表示
;;(setq initial-scratch-message "")
;; スプラッシュ画面の ON/OFF はこの変数で切り替える
;;   nil → 表示する（デフォルト）
;;   t   → 表示しない
(defvar my/disable-splash t)

;; ロゴを表示するために inhibit 設定を確実に nil にする
;; （my/disable-splash が t の場合は表示しない）
(setq inhibit-startup-message my/disable-splash)
(setq inhibit-startup-screen  my/disable-splash)

;; obsidian パッケージが起動時に command-line-args にディレクトリを追加するため
;; Emacs がスプラッシュ画面をスキップしてしまう。
;; window-setup-hook で強制的に表示することで回避する。
(add-hook 'window-setup-hook
          (lambda ()
            (when (and (not my/disable-splash)
                       fancy-splash-image
                       (file-exists-p fancy-splash-image))
              (fancy-startup-screen))))

;; 言語環境を日本語に
(set-language-environment "Japanese")

;; UTF-8 を優先しつつ、UTF-16/CP932 などのファイル自動判定は残す
;; （buffer-file-coding-system のデフォルトは、後段の tr-ime
;;   セクションで w32-ime-initialize 実行後に再設定している。
;;   ここで設定しても tr-ime 側に上書きされてしまうため）
(prefer-coding-system 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)
(set-selection-coding-system 'utf-16le-dos)

;; 「yes/no」を「y/n」の1文字で済ます
(fset 'yes-or-no-p 'y-or-n-p)

;; ナローイング機能（編集範囲の限定）を有効化
(put 'narrow-to-region 'disabled nil)

;; ビープ音を消す
(setq ring-bell-function 'ignore)

;; バックアップファイル（〜付き）を作らない
(setq make-backup-files nil)

;; 現代的なアプリのような滑らかなスクロール (Emacs 29+)
(when (fboundp 'pixel-scroll-precision-mode)
  (pixel-scroll-precision-mode 1))

;; 外部でのファイル変更を自動検知して反映
(global-auto-revert-mode 1)

;; 次回ファイルを開いた時に、前回のカーソル位置から再開
(use-package saveplace
  :ensure nil
  :config
  ;; ============================================================
  ;; 🌟 終了時の固まり対策（強化版）
  ;; with-timeout はファイルI/Oブロック中に機能しないため、
  ;; 保存先を確実にローカルな AppData に変更して固まりを防ぐ。
  ;; ポータブル版が USB/ネットワーク上にあっても問題なくなる。
  ;; ============================================================

  ;; 保存先を Windows のローカル AppData に固定する
  ;; （USB ドライブ上の .emacs.d に書くと固まる環境への対策）
  (setq save-place-file
        (expand-file-name "emacs/save-place" (or (getenv "LOCALAPPDATA") "c:/Temp")))

  ;; 保存先ディレクトリが存在しない場合は作成する
  (make-directory (file-name-directory save-place-file) t)

  (defun my/save-place-save-safe ()
    "タイムアウト付きで save-place を保存します。
with-timeout はファイルI/O中に効かないため、condition-case で
書き込みエラーを握りつぶして確実に終了できるようにします。"
    (condition-case err
        (let ((inhibit-message t))
          ;; ローカルファイルへの書き込みなので通常は即座に終わる
          (save-place-kill-emacs-hook))
      (error
       (message "save-place の保存をスキップしました: %s" (error-message-string err)))))

  ;; 標準フックを外して安全版を登録
  (remove-hook 'kill-emacs-hook #'save-place-kill-emacs-hook)
  (add-hook    'kill-emacs-hook #'my/save-place-save-safe)

  (save-place-mode 1))

;; ミニバッファの再帰呼び出しを許可（コマンド実行中に別のコマンドを呼べる）
(setq enable-recursive-minibuffers t)
(minibuffer-depth-indicate-mode 1)

;; txtファイルはtextモードに
(add-to-list 'auto-mode-alist '("\\.txt\\'" . text-mode))

;; --- Dired (ファイル管理) の強化 ---
(setq dired-dwim-target t)             ; 2画面分割時、コピー先などを自動提案
(setq dired-listing-switches "-alh")   ; サイズを KB/MB で表示
(with-eval-after-load 'dired
  ;; Dired 内で "E" を押すと Windows の関連付けアプリで開く
  (define-key dired-mode-map (kbd "E")
    (lambda () (interactive)
      (let ((file (dired-get-file-for-visit)))
        (w32-shell-execute "open" file)))))

;; カラー強制表示（GUI環境 / Windows 向け）
(setenv "TERM" "xterm-256color")
(setenv "COLORTERM" "truecolor")

;; =====================================================================
;; 1b. フレームサイズの記憶（前回終了時のサイズで起動）
;; ─ バッファは復元しない。位置・サイズだけ保存する。
;; =====================================================================

(defun my/save-frame-geometry ()
  "終了時にフレームの位置とサイズを保存します。"
  (let* ((frame  (selected-frame))
         (params (list (cons 'left   (frame-parameter frame 'left))
                       (cons 'top    (frame-parameter frame 'top))
                       (cons 'width  (frame-parameter frame 'width))
                       (cons 'height (frame-parameter frame 'height))))
         (file   (expand-file-name "frame-geometry.el" user-emacs-directory)))
    (with-temp-file file
      (insert ";; 自動生成ファイル。手動で編集しないでください。\n")
      (insert (format "(setq initial-frame-alist '%S)\n" params)))))

;; 起動時に復元・終了時に保存
;; early-init.el がない環境では init.el の先頭で直接ロードするのが確実
(let ((file (expand-file-name "frame-geometry.el" user-emacs-directory)))
  (when (file-exists-p file)
    (load file nil t)))
(add-hook 'kill-emacs-hook #'my/save-frame-geometry)

;; *scratch* バッファの内容を終了時に保存し、起動時に復元する
(use-package persistent-scratch
  :config
  (persistent-scratch-setup-default)
  ;; 自動保存（idle時・バッファ変更時）も有効にする
  (persistent-scratch-autosave-mode 1))


;; =====================================================================
;; 2. パッケージ管理（MELPA）
;; =====================================================================

(require 'package)
(setq package-archives
      '(("gnu"   . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/") 
        ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

;; パッケージリストが空の場合（初回起動・新環境）は MELPA から取得する
;; これにより use-package :ensure t が正しく機能してパッケージが自動インストールされる
(unless package-archive-contents
  (message "パッケージリストを取得中...")
  (package-refresh-contents))

;; use-package が未インストールの場合は自動インストール（Emacs 29 未満向け）
(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package-ensure)
(setq use-package-always-ensure t)

;; --- 起動時ダッシュボード画面 (emacs-dashboard) ---
(use-package dashboard
  :ensure t
  :demand t
  :bind
  (("<home>" . dashboard-refresh-buffer)
   :map dashboard-mode-map
   ("<home>" . quit-window)
   ("o" . hydra-launcher/body)
   ("e" . consult-locate)
   ("s" . my/consult-ripgrep-project)
   ("g" . my/consult-fd-project)
   ("f" . consult-recent-file)
   ("c" . conpty)
   ("p" . conpty-powershell)
   ("L" . my/open-calendar)
   ("d" . lookup)
   ("w" . hydra-window/body)
   ("F" . hydra-file/body))
  :config
  ;; 起動時にダッシュボードを表示する
  (dashboard-setup-startup-hook)
  
  ;; 指定のバナー画像を設定 (ポータブル対応)
  (let ((banner-path (expand-file-name "images/banner.png" user-emacs-directory)))
    (if (file-exists-p banner-path)
        (setq dashboard-startup-banner banner-path)
      (setq dashboard-startup-banner 'official))) ; 画像がない場合は標準ロゴ
  
  ;; タイトルメッセージ (ロゴのすぐ下にバージョン入りで表示)
  (setq dashboard-banner-logo-title (format "Welcome to GNU Emacs portable version %s" emacs-version))
  
  ;; 中央寄せ表示
  (setq dashboard-center-content t)
  
  ;; 表示するセクションと件数
  (setq dashboard-items '((recents  . 5)   ; 最近開いたファイル
                          (projects . 5)   ; プロジェクト一覧
                          (bookmarks . 5)  ; ブックマーク
                          (custom . nil))) ; クイックメニュー (カスタム)
  
  ;; カスタムセクションの描画関数
  (defun my/dashboard-insert-hydra-guide (list-size)
    (insert "\n=== 🚀 クイックメニュー (キーを押して直接実行 / [o] で全ランチャー表示) ===\n\n")
    (insert "  [e] Everything (PC検索)   [s] プロジェクト検索     [g] ファイル検索 (fd)\n")
    (insert "  [f] 最近使ったファイル     [w] ウィンドウ操作メニュー [d] 辞書検索 (Lookup)\n")
    (insert "  [L] カレンダー (calfw)     [p] PowerShell (conpty)  [c] cmd.exe (conpty)\n")
    (insert "  [F] ファイル操作メニュー   [o] メインメニュー (Hydra)\n"))

  ;; ジェネレーターの登録
  (add-to-list 'dashboard-item-generators '(custom . my/dashboard-insert-hydra-guide))

  ;; アイコン表示（Windows環境での文字化け防止のため無効化）
  (setq dashboard-set-heading-icons nil)
  (setq dashboard-set-file-icons nil)
  
  ;; フッターの非表示 (ロゴ下部分にバージョンを表示したため非表示)
  (setq dashboard-show-footer nil)
  
  (setq dashboard-show-shortcuts t)
  (setq dashboard-set-navigator t))


;; =====================================================================
;; 3. 外観（テーマ・フォント・UI）
;; =====================================================================

;; タブバー設定の初期化（過去のバグリセット）
(setq default-frame-alist (assq-delete-all 'tab-bar-lines default-frame-alist))

;; ★フォントポータブル仕様：.emacs.d/fonts/ のフォントを起動時に一時登録して最優先適用
;; 🌟 使いたいフォントファイル名はここで変更してください
(condition-case nil
    (let* ((my-fonts-dir   (expand-file-name "fonts/" user-emacs-directory))
           (my-font-file   "Utatane-Regular.ttf")
           (my-font-path   (expand-file-name my-font-file my-fonts-dir))
           (my-font-name   "Utatane")
           (my-font-setting (format "%s-13" my-font-name)))
      (when (file-exists-p my-font-path)
        (w32-register-font my-font-path))
      (let ((final-font (if (member my-font-name (font-family-list))
                            my-font-setting
                          "MS Gothic-13")))
        (set-face-attribute 'default        nil :font final-font)
        (set-face-attribute 'fixed-pitch    nil :font final-font)
        (set-face-attribute 'variable-pitch nil :font final-font)))
  (error (message "標準フォントで起動しました。")))

;; メニューバー・ツールバー・スクロールバーを表示
(menu-bar-mode 1)
(tool-bar-mode 1)
(set-scroll-bar-mode 'right)

(defun my/toolbar-consult-menu (event)
  "ツールバーをクリックした際に、Consult-line または Consult-outline を起動するメニューを表示します。"
  (interactive "e")
  (let ((menu (make-sparse-keymap "Consult検索")))
    (define-key menu [outline]
      '(menu-item "バッファ内アウトライン検索" consult-outline
                  :help "見出し（アウトライン）を一覧検索してジャンプします"))
    (define-key menu [line]
      '(menu-item "バッファ内行検索" consult-line
                  :keys "C-f"
                  :help "バッファ内のテキストを行ごとに高速検索してジャンプします"))
    (popup-menu menu event)))

(defun my/toolbar-filter-menu (event)
  "ツールバーをクリックした際に、moccur-edit または occur-edit を起動するメニューを表示します。"
  (interactive "e")
  (let ((menu (make-sparse-keymap "フィルタ検索")))
    (define-key menu [occur]
      '(menu-item "フィルタ (occur-edit - 標準)"
                  (lambda () (interactive) (my/emeditor-filter 'occur))
                  :keys "C-c f"
                  :help "標準の occur-edit を使用してフィルタします"))
    (define-key menu [moccur]
      '(menu-item "フィルタ (moccur-edit - Migemo対応)"
                  (lambda () (interactive) (my/emeditor-filter 'moccur))
                  :help "color-moccur (Migemo対応) を使用してフィルタします"
                  :enable (and (locate-library "color-moccur")
                               (locate-library "moccur-edit"))))
    (popup-menu menu event)))

;; ツールバーを Adwaita アイコンで全面置き換え
;; 🌟 アイコン画像の場所：~/.emacs.d/images/ に tb-*.png を配置してください
;;    （adwaita-icons.zip の中身をそのままコピー）

(defun my/tb-image (name)
  "~/.emacs.d/images/<name>.png を読み込んで image オブジェクトを返す。
見つからなければ nil。"
  (let ((path (expand-file-name (concat "images/" name ".png")
                                user-emacs-directory)))
    (when (file-exists-p path)
      (create-image path 'png nil :ascent 'center))))

(defun my/tb-add (key command icon-name help)
  "ツールバーにボタンを1つ追加する。アイコンがなければテキストボタンになる。"
  (let ((img (my/tb-image icon-name)))
    (define-key tool-bar-map (vector key)
      (if img
          `(menu-item ,help ,command :image ,img :help ,help)
        `(menu-item ,help ,command :help ,help)))))

(defun my/tb-sep (key)
  "ツールバーにセパレータを追加する。"
  (define-key tool-bar-map (vector key) '(menu-item "--")))

;; window-setup-hook でツールバーをまるごと再構築する
;; （標準ツールバーを一度クリアして Adwaita アイコンで並べ直す）
(add-hook 'window-setup-hook
          (lambda ()
            ;; 標準ボタンをすべて削除してまっさらにする
            (setq tool-bar-map (make-sparse-keymap))
            ;; make-sparse-keymap は後から追加したものが前に表示されるため
            ;; 逆順（末尾→先頭）で登録する
            ;; カスタムボタン（逆順）
            (my/tb-add '21b-close-win 'delete-window                    "tb-close"        "このウィンドウを閉じる")
            (my/tb-add '22-close-oth 'delete-other-windows             "tb-close-others" "他のウィンドウをすべて閉じる")
            (my/tb-add '21-split-v   'split-window-below               "tb-split-vert"   "画面を上下に2分割")
            (my/tb-add '20-split-h   'split-window-right               "tb-split-horiz"  "画面を左右に2分割")
            (my/tb-add '19-open-ext  'my-open-current-file-in-windows  "tb-open-ext"     "Windowsの関連付けプログラムで開く")
            (my/tb-add '18-encoding  'revert-buffer-with-coding-system "tb-encoding"     "文字コードを指定して開き直す")
            (my/tb-add '17-diff      'my-compare-with-winmerge         "tb-diff"         "WinMergeで差分を比較")
            (my/tb-sep '16-sep)
            ;; カラーマーカー
            (my/tb-add '15-marker-clr 'my/toolbar-marker-clear-menu    "tb-marker-clear" "マーカーを削除")
            (my/tb-add '14-marker-put 'my/marker-put                   "tb-marker"       "カラーマーカー付け/消し")
            (my/tb-sep '13-sep)
            ;; 検索・置換
            (my/tb-add '12c-replace   'my/visual-replace-menu   "tb-replace"      "置換")
            (my/tb-add '12b-filter    'my/toolbar-filter-menu   "tb-filter"       "フィルタ（マッチ行のみ表示・直接編集）")
            (my/tb-add '12-search-bwd 'isearch-backward         "tb-search-bwd"   "前を検索")
            (my/tb-add '11-search-fwd 'isearch-forward          "tb-search-fwd"   "後を検索")
            (my/tb-add '10b-consult   'my/toolbar-consult-menu  "tb-search"       "Consult検索 (行・アウトライン)")
            (my/tb-sep '10-sep)
            ;; 編集
            (my/tb-add '09-paste     'yank                             "tb-paste"        "貼り付け")
            (my/tb-add '08-copy      'kill-ring-save                   "tb-copy"         "コピー")
            (my/tb-add '07-cut       'kill-region                      "tb-cut"          "切り取り")
            (my/tb-sep '06-sep)
            (my/tb-add '06-redo      'undo-redo                        "tb-redo"         "やり直す")
            (my/tb-add '05-undo      'undo                             "tb-undo"         "元に戻す")
            (my/tb-sep '04-sep)
            ;; ファイル操作
            (my/tb-add '03-save      'save-buffer                      "tb-save"         "保存")
            (my/tb-add '02-open      'menu-find-file-existing          "tb-open"         "ファイルを開く")
            (my/tb-add '01-new       'find-file                        "tb-new"          "新規ファイルを開く")))

;; 現在の編集行を常時ハイライトする (hl-line)
(global-hl-line-mode 1)

;; カーソルを見失わないように、移動・スクロール時に光るエフェクトを追加 (beacon)
(use-package beacon
  :ensure t
  :config
  (beacon-mode 1)
  (setq beacon-size 35           ; エフェクトの幅
        beacon-blink-duration 0.3) ; エフェクト時間（秒）

  ;; テーマの明暗（Light/Dark）に合わせてビーコンの色を自動調整する
  (defun my/update-beacon-color (&rest _)
    (setq beacon-color
          (if (eq (frame-parameter nil 'background-mode) 'dark)
              "#00ffff"   ; ダークテーマ用（シアン / 水色）
            "#008b8b")))  ; ライトテーマ用（ダークシアン）
  ;; 初期反映およびテーマ切り替えフックへの登録
  (my/update-beacon-color)
  (add-hook 'enable-theme-functions #'my/update-beacon-color))

;; にゃんこバー（タイムライン進行度バー）
(use-package nyan-mode
  :config
  (setq nyan-wavy-trail t)
  (setq nyan-minimum-window-width 40)
  (nyan-mode 1)
  (nyan-start-animation))


;; 最近開いたファイルの履歴
(use-package recentf
  :ensure nil
  :config
  (setq recentf-max-saved-items 100)
  (setq recentf-exclude
        '("/\\.emacs\\.d/elpa/" "/emacs/share/"
          "^/\\(?:ssh\\|scp\\|ftp\\):"     ; リモートファイルを除外（固まり防止）
          "\\.recentf$"))                   ; recentf ファイル自体を除外

  ;; ============================================================
  ;; 🌟 ファイル生存確認（existence check）の ON/OFF スイッチ
  ;;   nil → 確認しない（起動・動作が速い。ネットワークドライブ多用時に推奨）
  ;;   t   → 確認する  （消えたファイルが履歴から自動で消える）
  ;; ============================================================
  (defvar my/recentf-existence-check nil
    "non-nil のとき recentf のファイル生存確認を有効にします。")

  (if my/recentf-existence-check
      (setq recentf-auto-cleanup 'mode)
    (setq recentf-auto-cleanup 'never))

  ;; recentf の保存ファイルを UTF-8 で書き出す（Windows環境での文字化け防止）
  (setq recentf-save-file-coding-system 'utf-8)

  ;; 定期自動保存はオフ（終了時のみ保存）
  (setq recentf-auto-save-timer nil)

  ;; ============================================================
  ;; 🌟 終了時の固まり対策
  ;; recentf-save-list を kill-emacs-hook から外し、
  ;; タイムアウト付きの安全な版に差し替える
  ;; ============================================================
  (defun my/recentf-save-safe ()
    "タイムアウト付きで recentf を保存します。3秒以内に終わらなければスキップします。"
    (let ((inhibit-message t))          ; 「Saving recentf...」メッセージを抑制
      (with-timeout (3 (message "recentf の保存をスキップしました（タイムアウト）"))
        (recentf-save-list))))

  ;; 標準フックを外して安全版を登録
  (remove-hook 'kill-emacs-hook #'recentf-save-list)
  (add-hook    'kill-emacs-hook #'my/recentf-save-safe)

  (recentf-mode 1))

;; recentf の代用：ミニバッファ履歴保存機能（savehist）
(use-package savehist
  :ensure nil
  :init
  (setq savehist-file (expand-file-name "savehist" user-emacs-directory))
  (setq savehist-additional-variables '(file-name-history)) ; ファイルを開いた履歴を強制記録
  (savehist-mode 1))


;; =====================================================================
;; 4. 表示・スクロール・行番号
;; =====================================================================

;; 対応カッコをハイライト
(show-paren-mode 1)
(setq show-paren-delay 0)
(setq show-paren-style 'mixed)

;; カッコの自動補完（electric-pair-mode）
(electric-pair-mode 1)

;; 対応するカッコを深さごとに色分けして見やすくする（rainbow-delimiters）
(use-package rainbow-delimiters
  :ensure t
  :hook (prog-mode . rainbow-delimiters-mode))

;; 単語で折り返し
(global-visual-line-mode 1)

;; スクロール設定
(setq scroll-conservatively 1)
(setq mouse-wheel-progressive-speed nil)
(setq mouse-wheel-follow-mouse t)
(setq scroll-preserve-screen-position t)
(setq scroll-margin 5)

;; 行番号を常時表示（最低3桁幅で固定）
(global-display-line-numbers-mode 1)
(setq display-line-numbers-width 3)
(setq display-line-numbers-grow-only t)

;; 全角スペース・TABをテーマに合わせた色で可視化（半角スペースは非表示）
(require 'whitespace)

;; 🌟 point1: space-mark を有効にしつつ、styleから「spaces（半角）」を除外。
;; これにより「全角スペース」と「TAB」だけがwhitespaceの管理対象になります。
(setq whitespace-style '(face tabs tab-mark spaces space-mark trailing))

;; 🌟 point2: 可視化する文字のマッピング
;; 半角スペースはマッピング自体を空にして完全に非表示（透明）にします。
(setq whitespace-display-mappings
      '((space-mark ?\u3000 [?\u25a1] [?_ ?_])       ;; 全角スペース → 「□」
        (tab-mark   ?\t     [?\u00BB ?\t] [?\\ ?\t]))) ;; TAB → 「»」

(global-whitespace-mode 1)

;; 🌟 point3: 色をテーマに完全連動させる
;; テーマが持つ「警告用（warning）」や「特殊文字用（escape-glyph）」のフェイスを
;; そのまま継承（コピー）するため、ライト/ダークどちらのテーマに変えても100%調和します。
(set-face-attribute 'whitespace-tab nil
                    :background 'unspecified
                    :foreground (face-attribute 'font-lock-warning-face :foreground)
                    :inverse-video nil
                    :weight 'bold)

(set-face-attribute 'whitespace-space nil
                    :background 'unspecified
                    :foreground (face-attribute 'escape-glyph :foreground)
                    :inverse-video nil
                    :weight 'normal)

;; 行末のスペース（半角・全角）をハイライト表示
(setq-default show-trailing-whitespace t)

;; 🌟 サクラエディタ風の正規表現キーワード強調表示（テキスト・Markdown用）
;; 各種括弧や引用符（「」『』()（）[]［］【】《》<>〈〉"" '' など）や丸数字①-⑳を色分けします。
(defconst my/text-highlight-keywords
  '(("「[^」]*」" . font-lock-string-face)
    ("『[^』]*』" . font-lock-string-face)
    ("([^)]*)" . font-lock-comment-face)
    ("（[^）]*）" . font-lock-comment-face)
    ("\\[[^]]*\\]" . font-lock-comment-face)
    ("［[^］]*］" . font-lock-comment-face)
    ("<<[^>]*>>" . font-lock-constant-face)
    ("<[^>]*>" . font-lock-constant-face)
    ("〈[^〉]*〉" . font-lock-constant-face)
    ("＜[^＞]*＞" . font-lock-constant-face)
    ("《[^》]*》" . font-lock-constant-face)
    ("【[^】]*】" . font-lock-keyword-face)
    ("[①-⑳]" . font-lock-warning-face)
    ("'[^']*'" . font-lock-string-face)
    ("\"[^\"]*\"" . font-lock-string-face)))

(font-lock-add-keywords 'text-mode my/text-highlight-keywords)


;; =====================================================================
;; 5. モードライン（情報行）のカスタマイズ（ご指定レイアウト ＆ パスホバー版）
;; =====================================================================

(line-number-mode 1)
(column-number-mode 1)

;; バッファの文字数を表示
(defun my-mode-line-character-count ()
  "現在のバッファの文字数を返します。"
  (format " [%s文字] " (number-to-string (buffer-size))))

;; 文字コード名をコンパクトに表示（[U8] や [SJIS] などの形式）
(defun my-modeline-coding-system ()
  "文字コード名をコンパクトに表示します。"
  (let* ((coding-sym (coding-system-base buffer-file-coding-system))
         (coding     (symbol-name coding-sym))
         (has-bom    (string-match "with-signature" coding))
         (suffix     (if has-bom "+BOM" "")))
    (cond
     ((string-match "utf-16"                    coding) (format " [U16%s] "  suffix))
     ((string-match "utf-8"                     coding) (format " [U8%s] "   suffix))
     ((string-match "japanese-cp932\\|shift_jis" coding) (format " [SJIS%s] " suffix))
     ((string-match "euc-jp"                    coding) (format " [EUC%s] "  suffix))
     (t (let ((short (replace-regexp-in-string
                      "-with-signature\\|-dos\\|-unix\\|-mac" "" coding)))
          (format " [%s%s] " (upcase short) suffix))))))

;; Cosense風：ファイルを編集した瞬間に「[*]」に変わる未保存マーク
;; ① [-] にも薄いグレーをつけて3状態を視覚的に区別
(defun my-modeline-modification-status ()
  "バッファの編集状態（未保存）をCosense風の記号で返します。"
  (cond
   ((not (buffer-file-name))
    (propertize " [-] " 'face '(:foreground "gray50")))          ; ファイルなし：グレー
   ((buffer-modified-p)
    (propertize " [*] " 'face '(:foreground "Orange" :weight bold))) ; 未保存：オレンジ
   (t
    (propertize " [ ] " 'face '(:foreground "gray70")))))        ; 保存済み：薄グレー

;; モード表示：現在のメジャーモード名を (Mode名) の形式で返す
(defun my-modeline-major-mode ()
  "現在のメジャーモード名を (mode名) の形式で返します。"
  (format " (%s) " (replace-regexp-in-string "-mode$" "" (symbol-name major-mode))))

;; ナローイング中（標準またはソフトナローイング）の表示
(defun my-modeline-narrow-status ()
  "ナローイング中の場合に [narrow] を返します。"
  (if (or (bound-and-true-p my/fancy-narrow-mode)
          (buffer-narrowed-p))
      (propertize " [narrow] " 'face '(:foreground "Orange" :weight bold))
    ""))

;; 🌟 ホバーでフルパスが表示されるファイル名
(defun my-modeline-buffer-name-with-path-help ()
  "マウスホバー時にフルパスをポップアップ表示するバッファ名を返します。"
  (let ((full-path (or buffer-file-name (buffer-name))))
    (propertize "%b"
                'face '(:weight bold)
                'help-echo full-path))) ; 💡 マウスを乗せたときに Windows 風にフルパスをポップアップ

;; 時計の表示形式
(setq display-time-string-forms '((format-time-string "%Y/%m/%d(%a) %H:%M")))
(setq display-time-24hr-format t)
(setq display-time-mail-string "")
(display-time-mode 1)

;; 🌟 レイアウトをご指定の並び順に完全固定
(setq-default mode-line-format
  (list
   '(:eval (my-modeline-modification-status))        ; 1. [*]
   '(:eval (my-modeline-buffer-name-with-path-help)) ; 2. ノート.md（ホバーでフルパス）
   '(:eval (my-modeline-major-mode))                 ; 3. (markdown)
   '(:eval (my-modeline-narrow-status))              ; 🌟 [narrow] (ナローイング中のみ表示)
   '(:eval (my-modeline-coding-system))              ; 4. [U8]
   " "
   "行:%l/列:%c"                                     ; 5. 行:1/列:1
   " "
   '(:eval (my-mode-line-character-count))           ; 6. [121文字]
   " "
   '(:eval (when (bound-and-true-p nyan-mode) (nyan-create))) ; 7. ...ニャンコ...
   ;; 時計を右端に寄せる
   '(:eval (let* ((clock-str (or (and (boundp 'display-time-string) display-time-string) ""))
                  (margin    (max 0 (- (window-total-width) (length clock-str) 42))))
             (propertize " " 'display `(space :align-to ,margin))))
   '(:propertize display-time-string face bold)
   " "))

;; 🌟 不要なサイドバー・ツリー等のウィンドウでモードラインを非表示にする
(use-package hide-mode-line
  :ensure t
  :hook
  ((neotree-mode imenu-list-major-mode minimap-mode) . hide-mode-line-mode))

;; 🌟 タイトルバーのカスタマイズ（ドライブ名大文字化 ＆ パソコン名自動取得版）
(setq frame-title-format
      (list
       ;; 1. (フルパス) の先頭（ドライブ名）を大文字にして表示
       '(:eval (let ((path (or buffer-file-name (buffer-name))))
                 (format "%s" (if (string-match "^[a-z]:" path)
                                  ;; ドライブ文字だけ大文字にする（capitalize はパス全体に作用するため使わない）
                                  (concat (upcase (substring path 0 1)) (substring path 1))
                                path))))
       ;; 2.  Gnu Emacs at パソコン名（system-name関数でPC名を正しく取得）
       '(:eval (format " - GNU Emacs @ %s" system-name))))

;; =====================================================================
;; 6. タブバー（Centaur Tabs）
;; =====================================================================

(use-package centaur-tabs
  :demand t
  :config
  (setq centaur-tabs-set-bar   'top)
  (setq centaur-tabs-set-icons nil)
  (setq centaur-tabs-style     "bar")
  (setq centaur-tabs-height    26)
  (setq centaur-tabs-set-close-button t) ; 閉じるボタン（Xボタン）を有効にする
  ;; 通常バッファと内部バッファ（*scratch* など）の2グループに分け、
  ;; 内部バッファは右側（後方）のグループとして表示する。
  ;; centaur-tabs はグループをアルファベット順などで並べるため、
  ;; 内部バッファ側のグループ名を後方に来る文字列にしている。
  (defun centaur-tabs-buffer-groups ()
    (list
     (if (string-prefix-p "*" (buffer-name))
         "zzz-Internal"   ; 内部バッファ → 右側に表示
       "Buffers")))       ; 通常バッファ

  ;; タブは全部表示する（非表示ルールを無効化）
  (defun centaur-tabs-hide-tab (buffer) nil)
  ;; 注意: zzz-Internal グループのタブは編集中バッファのグループ表示中は
  ;; タブバー上に見えなくなるが、F2 (consult-buffer) で一覧から選択・
  ;; 切り替えは常に可能。
  (centaur-tabs-mode 1)
  :bind
  (("C-<tab>"   . centaur-tabs-forward)
   ("C-S-<tab>" . centaur-tabs-backward)))


;; =====================================================================
;; 7. Windows 連携コマンド
;; =====================================================================

;; 現在のファイルを Windows の関連付けプログラムで開く
(defun my-open-current-file-in-windows ()
  "今開いているファイルをWindowsの関連付けプログラムで開きます。"
  (interactive)
  (cond
   ((not buffer-file-name)
    (message "外部で開けるファイルバッファではありません。"))
   ((not (file-exists-p buffer-file-name))
    (message "ファイルがまだ保存されていません。"))
   (t
    (w32-shell-execute "open" buffer-file-name)
    (message "外部プログラムで開きました: %s" (file-name-nondirectory buffer-file-name)))))

(defun my/open-any-file-in-windows (file)
  "ミニバッファで選択した任意のファイルをWindowsの関連付けプログラムで開きます。"
  (interactive
   (list (read-file-name "外部アプリで開くファイルを選択: " nil nil t)))
  (if (and file (file-exists-p file))
      (progn
        (w32-shell-execute "open" file)
        (message "外部プログラムで開きました: %s" (file-name-nondirectory file)))
    (message "有効なファイルではありません: %s" file)))

(defun my/open-recent-file-in-windows ()
  "最近使ったファイルリストから選択し、Windowsの関連付けプログラムで直接開きます。"
  (interactive)
  (let* ((recent-files recentf-list)
         (file (completing-read "外部アプリで開く最近のファイル: " recent-files nil t)))
    (if (and file (file-exists-p file))
        (progn
          (w32-shell-execute "open" file)
          (message "外部プログラムで開きました: %s" (file-name-nondirectory file)))
      (message "有効なファイルではありません: %s" file))))

;; 🌟 デフォルトの m3u8/m3u プレイリストファイルパスをここで設定してください
;; 例: "c:/Music/mylist.m3u8"
;; nil にすると毎回ファイル選択ダイアログが開きます
(defvar my/m3u8-default-playlist
  (expand-file-name "TOROID/PPx/userdata/l_mp3filelist.m3u8"
                     (or (getenv "APPDATA") "c:/"))
  "my/m3u8-search-and-play で使うデフォルトのプレイリストファイルパス。
%APPDATA% (環境変数) を起点に解決する。nil にすると毎回ダイアログで選択します。")

(defun my/m3u8-normalize-path (raw)
  "Windows の バックスラッシュ パスを Emacs 用スラッシュに変換し BOM・空白を除去する。"
  (let* ((s (string-trim raw))
         (s (replace-regexp-in-string "\\`[\xef\xbb\xbf\xff\xfe]+" "" s))
         (s (replace-regexp-in-string "\\\\" "/" s)))
    s))

(defun my/m3u8-parse-entries (playlist-file)
  "m3u/m3u8 ファイルを読み込み (表示名 . パス) のリストを返す。
EXTINF 行があれば曲名を、なければファイル名を表示名にする。
Windows バックスラッシュパスは自動でスラッシュに変換する。"
  (let ((base-dir (file-name-directory (expand-file-name playlist-file)))
        entries
        current-title)
    (with-temp-buffer
      (let ((coding-system-for-read 'utf-8-with-signature))
        (insert-file-contents playlist-file))
      (goto-char (point-min))
      (while (not (eobp))
        (let ((line (my/m3u8-normalize-path
                     (or (thing-at-point 'line t) ""))))
          (cond
           ((string-match "^#EXTINF:[^,]*,\\(.*\\)$" line)
            (setq current-title (string-trim (match-string 1 line))))
           ((string-prefix-p "#" line) nil)
           ((string-empty-p line) nil)
           (t
            (let* ((fpath (if (string-match-p "^[a-zA-Z]:/" line)
                              line
                            (expand-file-name line base-dir)))
                   (label (or current-title (file-name-nondirectory fpath))))
              (push (cons label fpath) entries)
              (setq current-title nil)))))
        (forward-line 1)))
    (nreverse entries)))

(defun my/m3u8-candidates (entries)
  "ENTRIES から補完用の (表示文字列 . パス) alist を作る。"
  (let ((seen (make-hash-table :test 'equal)))
    (mapcar
     (lambda (entry)
       (let* ((title (car entry))
              (path (cdr entry))
              (base-label (if (string-empty-p title)
                              (file-name-nondirectory path)
                            title))
              (count (1+ (gethash base-label seen 0)))
              (label (if (= count 1)
                         base-label
                       (format "%s  <%d>" base-label count)))
              (candidate (format "%s    %s" label path)))
         (puthash base-label count seen)
         (cons candidate path)))
     entries)))

(defun my/m3u8-search-and-play ()
  "m3u/m3u8 プレイリストの曲を検索して外部プレイヤーで再生する。
固定パスは my/m3u8-default-playlist で設定。
C-u 付きで実行するとダイアログでファイルを選び直せる。

複数曲を選びたい場合: 曲名を入力 → TAB で確定 → `,` を入力すると
次の曲を選べる状態になる。これを繰り返し、最後に RET で確定すると
選んだ曲がすべて再生される。
1曲だけ再生する場合は、TAB で確定後に `,` を入力せず RET でよい。"
  (interactive)
  (let* ((playlist
          (if (and my/m3u8-default-playlist
                   (not current-prefix-arg)
                   (file-exists-p my/m3u8-default-playlist))
              my/m3u8-default-playlist
            (read-file-name
             "プレイリストを選択 (.m3u/.m3u8): "
             (if my/m3u8-default-playlist
                 (file-name-directory my/m3u8-default-playlist)
               "c:/")
             nil t nil
             (lambda (f)
               (or (file-directory-p f)
                   (string-match-p "\\.m3u8?$" f))))))
         (entries (my/m3u8-parse-entries playlist)))
    (if (null entries)
        (message "曲が見つかりませんでした: %s" playlist)
      (let* ((candidates
              (my/m3u8-candidates entries))
             (chosen-list
              (let ((orderless-matching-styles
                     '(orderless-literal orderless-regexp orderless-migemo)))
                (completing-read-multiple
                 (format "[%s] 曲を選択、複数はカンマ区切り (%d 曲): "
                         (file-name-nondirectory playlist)
                         (length entries))
                 candidates nil t)))
             (paths (delq nil
                          (mapcar (lambda (c)
                                    (alist-get c candidates nil nil #'string=))
                                  chosen-list))))
        (if (null paths)
            (message "曲が選択されませんでした。")
          (dolist (fpath paths)
            (if (file-exists-p fpath)
                (progn
                  (w32-shell-execute "open" (subst-char-in-string ?/ ?\\ fpath))
                  (message "再生: %s" (file-name-nondirectory fpath)))
              (message "ファイルが存在しません: %s" fpath))))))))


;; タブバー・モードラインのダブルクリックで外部プログラム起動
(with-eval-after-load 'centaur-tabs
  (define-key centaur-tabs-mode-map
    [header-line double-mouse-1] 'my-open-current-file-in-windows)
  ;; ---------------------------------------------------------------
  ;; 🌟 タブ左クリック・中クリックの挙動修正
  ;; タブ本体は centaur-tabs-default-map を使用。
  ;; mouse-1 → 選択（明示固定）
  ;; mouse-2 → ignore（nil だと "undefined" エラーになる）
  ;; ---------------------------------------------------------------
  (defun my/centaur-tabs-fix-mouse-bindings ()
    (when (and (boundp 'centaur-tabs-default-map)
               (boundp 'centaur-tabs-display-line))
      (define-key centaur-tabs-default-map
        (vector centaur-tabs-display-line 'mouse-1) 'centaur-tabs-do-select)
      (define-key centaur-tabs-default-map
        (vector centaur-tabs-display-line 'mouse-2) #'ignore)))
  (if (featurep 'centaur-tabs-functions)
      (my/centaur-tabs-fix-mouse-bindings)
    (with-eval-after-load 'centaur-tabs-functions
      (my/centaur-tabs-fix-mouse-bindings))))
(global-set-key [mode-line double-mouse-1] 'my-open-current-file-in-windows)

;; WinMerge で差分比較
(defun my-compare-with-winmerge ()
  "今開いているファイルをWinMergeで差分比較します。
2画面分割中は両方のファイルを比較、1画面のみの場合は同一ファイルを対象にします。"
  (interactive)
  (let ((winmerge-path
         (or (executable-find "WinMergeU.exe")
             (cl-find-if #'file-exists-p
                         (list (expand-file-name "WinMerge/WinMergeU.exe" (or (getenv "ProgramFiles") "C:/Program Files"))
                               (expand-file-name "WinMerge/WinMergeU.exe" (or (getenv "ProgramFiles(x86)") "C:/Program Files (x86)")))))))
    (if (not winmerge-path)
        (message "WinMergeU.exe が見つかりませんでした。インストールパスを確認してください。")
      (if (not buffer-file-name)
          (message "現在開いているバッファはファイルではありません。")
        (let* ((file1      buffer-file-name)
               (other-win  (next-window))
               (file2      (if (and (not (eq (selected-window) other-win))
                                   (buffer-file-name (window-buffer other-win)))
                               (buffer-file-name (window-buffer other-win))
                             file1)))
          (w32-shell-execute "open" winmerge-path
                             (format "\"%s\" \"%s\"" file1 file2))
          (message "WinMergeで比較中: %s" (file-name-nondirectory file1)))))))

(global-set-key (kbd "C-S-d") 'my-compare-with-winmerge)


;; =====================================================================
;; 8. キーバインド
;; =====================================================================

;; --- CUA モード（Windows風 C-c/C-v/C-z）---
(cua-mode 1)
(setq cua-keep-region-after-copy nil)  ; コピー後も選択範囲をクリア
(delete-selection-mode t)              ; 選択範囲に直接上書き入力できるようにする
(setq select-enable-clipboard t)
(setq save-interprogram-paste-before-kill t)

;; CUA モードの C-x キー設定
;; cua-mode は標準で「選択中は C-x で切り取り、非選択中は C-x プレフィックス」を
;; 自動的にハンドリングするため、上書き不要。
;; cua-enable-cua-keys を明示的に t にして標準動作を保証する。
(setq cua-enable-cua-keys t)

;; =====================================================================
;; Alt+ドラッグで矩形選択する
;; ─ 標準の secondary-selection（M-drag-mouse-1）を上書きし、
;;   Windows系エディタのような Alt+ドラッグ矩形選択に置き換える
;; =====================================================================

(defun my/mouse-drag-rectangle (start-event)
  "Alt+ドラッグで矩形選択(rectangle-mark-mode)を行う。"
  (interactive "e")
  (mouse-minibuffer-check start-event)
  (let* ((start-posn (event-start start-event))
         (start-point (posn-point start-posn))
         (start-window (posn-window start-posn))
         event)
    (select-window start-window)
    (goto-char start-point)
    (push-mark start-point nil t)
    (rectangle-mark-mode 1)
    (track-mouse
      (catch 'my/rectangle-drag-done
        (while t
          (setq event (read-event))
          ;; 溜まっている移動イベントは古いものを捨てて最新の1つだけ処理する
          ;; （これによりドラッグ中の余分な再描画を減らし、引っかかりを軽減する）
          (while (and (mouse-movement-p event) (input-pending-p))
            (setq event (read-event)))
          (let* ((posn (event-end event))
                 (point (and posn (posn-point posn))))
            (when point
              (goto-char point)))
          (unless (or (mouse-movement-p event)
                      (memq (car-safe event) '(switch-frame select-window)))
            (throw 'my/rectangle-drag-done t)))))))

;; secondary-selection 用のデフォルトバインドを解除してから割り当てる
;; ※ マウスイベント+Modifierは (kbd "...") ではなくベクタ形式で指定する
(global-unset-key [M-down-mouse-1])
(global-set-key [M-down-mouse-1] #'my/mouse-drag-rectangle)

;; Windows風に Esc キーでも矩形選択を解除できるようにする
(with-eval-after-load 'rect
  (define-key rectangle-mark-mode-map (kbd "<escape>") #'keyboard-quit))

;; Windows 系ショートカット
(global-set-key (kbd "C-z") 'undo)
(global-set-key (kbd "C-y") 'undo-redo)
(global-set-key (kbd "C-s") 'save-buffer)
(global-set-key (kbd "C-a") 'mark-whole-buffer)
(global-set-key (kbd "C-o") 'menu-find-file-existing) ; Windows ネイティブダイアログで開く
(global-set-key (kbd "C-w") 'kill-current-buffer)

;; C-e に行頭（インデント先頭）・行末のスマートトグルを割り当て
(defun my/toggle-beginning-end-of-line-smart ()
  "行末, インデントの先頭, 本当の行頭をトグルで移動します。
カーソルが行末にある場合：インデント先頭へ移動。（ただし空行等の場合は本当の行頭へ）
カーソルがインデント先頭にある場合：本当の行頭と異なる場合は本当の行頭へ、同じ場合は行末へ移動。
それ以外の場合：行末へ移動。"
  (interactive)
  (let ((orig-point (point)))
    (back-to-indentation)
    (let ((indent-point (point)))
      (goto-char orig-point)
      (cond
       ;; 1. 行末にいる場合
       ((eolp)
        (if (= (point) indent-point)
            (move-beginning-of-line nil)
          (goto-char indent-point)))
       ;; 2. インデント先頭にいる場合
       ((= orig-point indent-point)
        (let ((bol-point (save-excursion
                           (move-beginning-of-line nil)
                           (point))))
          (if (= indent-point bol-point)
              (move-end-of-line nil)
            (move-beginning-of-line nil))))
       ;; 3. それ以外（本当の行頭、行の中途など）
       (t
        (move-end-of-line nil))))))
(global-set-key (kbd "C-e") #'my/toggle-beginning-end-of-line-smart)

;; C-c = : xyzzy 風 calc-onthespot（選択範囲 or カーソル直前の数式を自動計算・置換）
;; 関数本体は右クリックメニューセクションで定義されているため、
;; with-eval-after-load ではなく after-init-hook で遅延バインドする
(add-hook 'after-init-hook
          (lambda ()
            (global-set-key (kbd "C-c =") #'my/ctx-calc-onthespot)))

;; F キー系
(global-set-key [f4]         'speedbar-get-focus) ;; F4 でスピードバー
;; F5: howm 環境 ON/OFF トグル
;; 　howm バッファが存在する → howm-kill-all で全消去（OFF）
;; 　howm バッファがない     → howm-menu を開く（ON）
(defun my/howm-toggle ()
  "howm 関連バッファが存在すれば howm-kill-all で全消去。なければ howm-menu を開く。"
  (interactive)
  (if (cl-some (lambda (buf)
                 (string-match-p "\\*howm" (buffer-name buf)))
               (buffer-list))
      (progn
        (howm-kill-all)
        ;; *Ilist* は howm-kill-all の対象外なので別途閉じる
        (when-let ((ilist-win (get-buffer-window "*Ilist*")))
          (delete-window ilist-win)))
    (howm-menu)))
(global-set-key [f5] 'my/howm-toggle) ;; F5 で howm 環境トグル
(global-set-key (kbd "<menu>") 'context-menu-open) ;; Menu キーで右クリック

;; F3: 検索開始 / 次を検索（兼用、前方）
;; S-F3: 検索開始 / 前を検索（兼用、後方）
;; isearch-mode 外で isearch-forward/backward を直接呼ぶと
;; 「検索文字列なし」状態でも repeat 扱いになり
;; "no previous search string" エラーになるため、
;; isearch-mode かどうかで呼び分けるラッパーを用意する。
(defun my/isearch-forward-or-repeat ()
  (interactive)
  (if isearch-mode
      (isearch-repeat-forward)
    (isearch-forward)))

(defun my/isearch-backward-or-repeat ()
  (interactive)
  (if isearch-mode
      (isearch-repeat-backward)
    (isearch-backward)))

(global-set-key (kbd "<f3>")   'my/isearch-forward-or-repeat)
(global-set-key (kbd "S-<f3>") 'my/isearch-backward-or-repeat)

(with-eval-after-load 'isearch
  (define-key isearch-mode-map (kbd "<f3>")   'isearch-repeat-forward)
  (define-key isearch-mode-map (kbd "S-<f3>") 'isearch-repeat-backward))


;; =====================================================================
;; 9. Windows シェル連携
;; =====================================================================

;; emacs-conpty (Windows ConPTY Proxy)
;; ビルド済みの emacs-conpty.exe を使用して、日本語やエスケープシーケンスを正しく表示します。
(let ((conpty-dir (expand-file-name "lisp/" user-emacs-directory)))
  (when (file-directory-p conpty-dir)
    (add-to-list 'load-path conpty-dir)
    (use-package conpty
      :ensure nil
      :commands (conpty conpty-powershell)
      :config
      (setq conpty-program (expand-file-name "bin/emacs-conpty.exe"
                                             (expand-file-name ".." user-emacs-directory))))))

;; 🌟 ドラッグ＆ドロップでファイルを開く挙動を強制的に有効化
(setq dnd-protocol-alist
      '(("^file:///" . dnd-open-local-file)
        ("^file://"  . dnd-open-local-file)
        ("^file:"    . dnd-open-local-file)))

;; =====================================================================
;; 10. Migemo（日本語ローマ字検索）
;; =====================================================================

(use-package migemo
  :config
  (setq migemo-command
        (or (executable-find "cmigemo")
            (expand-file-name "bin/cmigemo.exe" (expand-file-name ".." user-emacs-directory))))
  (setq migemo-options '("-q" "-e"))
  (if-let ((cmigemo-path (executable-find "cmigemo")))
      (progn
        (setq migemo-dictionary
              (expand-file-name "dict/utf-8/migemo-dict"
                                (file-name-directory cmigemo-path)))
        (setq migemo-user-dictionary  nil)
        (setq migemo-regex-dictionary nil)
        (setq migemo-coding-system    'utf-8-unix)
        (migemo-init))
    (message "【お知らせ】cmigemo が見つからないため Migemo を無効化しています。")))


;; =====================================================================
;; 10b. color-moccur ＆ moccur-edit（Migemo対応検索・一括編集）
;; =====================================================================

(add-to-list 'load-path (expand-file-name "site-lisp" user-emacs-directory))

(use-package color-moccur
  :ensure nil
  :commands (moccur moccur-search-files moccur-search-files-with-color)
  :bind (:map isearch-mode-map
         ("M-o" . isearch-moccur))
  :config
  ;; Migemoを利用できる環境であればMigemoを使う
  (when (and (executable-find "cmigemo") (require 'migemo nil t))
    (setq moccur-use-migemo t))
  
  ;; スペース区切りでAND検索を可能にする
  (setq moccur-split-word t)

  ;; 🔍 moccur表示中にヘッダーラインに操作説明を表示
  (advice-add 'moccur-mode :after
              (lambda (&rest _)
                (setq header-line-format
                      (propertize
                       "  🔍 moccur表示中  |  r: 編集モードに入る  |  q: 閉じる"
                       'face '(:background "#1a3a5c" :foreground "#aed6f1" :weight bold))))))

(use-package moccur-edit
  :ensure nil
  :after color-moccur
  :config
  ;; ✏ moccur-edit編集中にヘッダーラインを編集モード用に切り替え
  (advice-add 'moccur-edit-mode-in :after
              (lambda (&rest _)
                (setq header-line-format
                      (propertize
                       "  ✏ moccur編集中  |  C-c C-c: 変更を元ファイルに保存  |  C-c C-k: 編集をキャンセル"
                       'face '(:background "#3a1a1a" :foreground "#f4b8b8" :weight bold)))))

  ;; 🔍 編集モード終了時にヘッダーラインを元に戻す
  (advice-add 'moccur-edit-reset-key :after
              (lambda (&rest _)
                (setq header-line-format
                      (propertize
                       "  🔍 moccur表示中  |  r: 編集モードに入る  |  q: 閉じる"
                       'face '(:background "#1a3a5c" :foreground "#aed6f1" :weight bold))))))


;; =====================================================================
;; 11. 補完エコシステム（Vertico / Orderless / Consult / Embark / Hydra）
;; =====================================================================

(use-package vertico
  :init (vertico-mode)
  :config
  (setq vertico-count 20))

;; vertico-posframe — 候補リストをカーソル近くにポップアップ表示
;; consult-line / consult-ripgrep 等の候補をミニバッファではなく
;; フレーム内のポップアップウィンドウに表示する
;; vertico-multiform + vertico-posframe の組み合わせで
;; my/consult-line-symbol-at-point（popup-search相当）だけ posframe を使い、
;; 他はすべて通常のミニバッファ表示にする。
(use-package vertico-posframe
  :after vertico
  :config
  ;; posframe のデフォルト設定（posframe が使われるコマンド向け）
  (setq vertico-posframe-poshandler #'posframe-poshandler-point-bottom-left-corner)
  (setq vertico-posframe-width  100
        vertico-posframe-height 20)
  (setq vertico-posframe-border-width 2))

;; vertico-multiform でコマンドごとの表示方式を切り替える
;; my/consult-line-symbol-at-point だけ posframe、それ以外はデフォルト（ミニバッファ）
(use-package vertico-multiform
  :ensure nil  ; vertico に同梱
  :after vertico-posframe
  :config
  (setq vertico-multiform-commands
        '((my/consult-line-symbol-at-point posframe)))
  (vertico-multiform-mode 1))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion))))
  :config
  ;; Migemo を orderless のマッチ戦略として追加
  (defun orderless-migemo (component)
    (if (and (fboundp 'migemo-get-pattern) (featurep 'migemo))
        (let ((pattern (migemo-get-pattern component)))
          (condition-case nil
              (progn (string-match pattern "") pattern)
            (invalid-regexp component)))
      component))
  (setq orderless-matching-styles
        '(orderless-literal
          orderless-regexp
          orderless-initialism   ; 頭文字マッチ (例: "fb" で "foo-bar")
          ;;orderless-flex         ; まさに fzf 風の曖昧マッチ (例: "ax" で "apple-index") 
          ;;\b（keyword）と入力しないと検索結果にノイズが多く乗るのでOFF
          orderless-migemo)))   ; ローマ字日本語マッチ

(use-package marginalia
  :init (marginalia-mode))

;; --- Corfu (ポップアップ補完 UI) ---
(use-package corfu
  :custom
  (corfu-auto t)                 ; 入力中に自動でポップアップ
  (corfu-auto-delay 0.1)         ; ポップアップまでの遅延（秒）
  (corfu-auto-prefix 2)          ; 2文字以上で補完開始
  (corfu-cycle t)                ; 候補をループさせる
  :init
  (global-corfu-mode)
  ;; TAB での補完挙動を調整（インデント済みなら補完を開始）
  (setq tab-always-indent 'complete))

;; --- Cape (補完バックエンド拡張) ---
(use-package cape
  :init
  ;; dabbrev (バッファ内の単語) を補完候補に追加
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  ;; ファイルパスを補完候補に追加
  (add-to-list 'completion-at-point-functions #'cape-file)
  ;; Elisp のコードブロック内での補完
  (add-to-list 'completion-at-point-functions #'cape-elisp-block))

;; 🌟 ispell の辞書が存在しないため ispell-completion-at-point を無効化する
;; （Corfu が毎回 "No plain word-list found" エラーを出すのを防ぐ）
(with-eval-after-load 'ispell
  ;; ポータブル環境に辞書がないため、ispell 補完を完全に無効化
  (setq ispell-alternate-dictionary nil)
  ;; ispell-completion-at-point が capf に追加されても動かないようにする
  (defun ispell-completion-at-point () nil))

;; ispell-completion-at-point をグローバル capf リストから除去
(setq completion-at-point-functions
      (remove #'ispell-completion-at-point completion-at-point-functions))


;; --- Hydra メニュー ---
(use-package hydra)

;; プロジェクトルートから ripgrep 検索
(defun my/consult-ripgrep-project ()
  "現在の project.el ルートを対象に consult-ripgrep を実行します。"
  (interactive)
  (if-let ((project (project-current)))
      (consult-ripgrep (project-root project))
    (call-interactively #'consult-ripgrep)))

(defun my/consult-ripgrep-word (&optional dir)
  "カーソル位置の単語を完全一致で ripgrep 検索する。
\b の代わりに lookbehind/lookahead を使うことで fd-find のようなハイフン含む
単語も正しくマッチする。C-u を付けると検索ディレクトリを選択できる。"
  (interactive "P")
  (let* ((search-dir
          (cond
           (dir (read-directory-name "検索ディレクトリ: " nil nil t))
           ((project-current) (project-root (project-current)))
           (t nil)))
         (default (thing-at-point 'symbol t)) ; word ではなく symbol でハイフン込みで取得
         (word (read-string
                (format "単語検索%s: "
                        (if default (format " [%s]" default) ""))
                nil nil default)))
    ;; (?<!\w)(?<!-) : 直前が英数字またはハイフンでない（PCRE2 では [\w-] はブラケット内不可）
    ;; (?!\w)(?!-)  : 直後が英数字またはハイフンでない
    (consult-ripgrep search-dir (concat "(?<!\w)(?<!-)" word "(?!\w)(?!-)"))))

;; C-c r w に割り当て
(global-set-key (kbd "C-c r w") #'my/consult-ripgrep-word)

;; Migemo を強制して consult-line を起動
(defun my/consult-line-migemo ()
  "通常検索と Migemo（ローマ字で日本語検索）を併用して consult-line を起動します。"
  (interactive)
  (let ((consult--regexp-compiler #'my/consult-migemo-compiler))
    (consult-line)))

;; 選択範囲があればその文字列を、なければカーソル下の単語を consult-line で検索
(defun my/consult-line-symbol-at-point ()
  "選択範囲（またはカーソル下の単語）を即 consult-line 検索する。
選択範囲の場合はそのまま、単語の場合は単語境界マッチ。"
  (interactive)
  (cond
   ((use-region-p)
    (let ((text (buffer-substring-no-properties (region-beginning) (region-end))))
      (deactivate-mark)
      (consult-line (regexp-quote text))))
   (t
    (let ((word (thing-at-point 'symbol t)))
      (if word
          (consult-line (concat "\\<" (regexp-quote word) "\\>"))
        (consult-line))))))

(global-set-key (kbd "C-c l") #'my/consult-line-symbol-at-point)

;; コピー・切り取り時にミニバッファへ通知メッセージを表示
(defun my/kill-ring-notify (orig-fn beg end &rest args)
  "kill-ring-save / kill-region の後にコピー・切り取り文字数を通知する。"
  (let ((text (buffer-substring-no-properties beg end)))
    (apply orig-fn beg end args)
    (message "クリップボード: [%s]%s"
             (truncate-string-to-width text 40 nil nil "…")
             (if (> (length text) 40) "" ""))))
(advice-add 'kill-ring-save :around #'my/kill-ring-notify)
(advice-add 'kill-region     :around #'my/kill-ring-notify)
;; CUA モードの C-c コピーは cua-copy-region を使うため別途通知
(defun my/cua-copy-notify (&rest args)
  "cua-copy-region の後にコピー内容を通知する。"
  (when (use-region-p)
    (let ((text (buffer-substring-no-properties (region-beginning) (region-end))))
      (message "クリップボード: [%s]%s"
               (truncate-string-to-width text 40 nil nil "…")
               (if (> (length text) 40) "" "")))))
(advice-add 'cua-copy-region :after #'my/cua-copy-notify)

;; ウィンドウ・バッファ管理メニュー（:color red で閉じるまで連打可能）
(defhydra hydra-window (:color red :hint nil)
  "
  === WINDOW & BUFFER (M-o w) ===
  [分割]                    [移動・サイズ]              [閉じる]
  [_2_] 上下に分割          [_o_] 次のウィンドウへ      [_0_] このウィンドウを閉じる
  [_3_] 左右に分割          [_O_] 前のウィンドウへ      [_1_] 他をすべて閉じる
                            [_=_] 幅・高さをそろえる    [_k_] バッファを閉じる
                            [_+_] 高さを広げる          [_K_] バッファ＋ウィンドウを閉じる
                            [_-_] 高さを縮める
  ----------------------------------------------------------------------
  [_q_] 閉じる
"
  ;; 分割
  ("2" split-window-below)
  ("3" split-window-right)
  ;; 移動・サイズ調整
  ("o" other-window)
  ("O" (other-window -1))
  ("=" balance-windows)
  ("+" enlarge-window)
  ("-" shrink-window)
  ;; 閉じる
  ("0" delete-window)
  ("1" delete-other-windows)
  ("k" kill-current-buffer)
  ("K" (progn (kill-current-buffer) (delete-window)))
  ("q" nil :color blue))

(defun my/run-in-external-terminal (shell cmd)
  "CMD を SHELL ('cmd または 'powershell) の外部ターミナルウィンドウで実行します。
wt.exe があれば Windows Terminal で、なければ標準のコンソール（ConHost）で起動します。"
  (let* ((wt (or (executable-find "wt.exe") (executable-find "wt")))
         (file-path (buffer-file-name))
         (run-dir (if file-path
                      (expand-file-name (file-name-directory file-path))
                    (expand-file-name default-directory)))
         ;; PowerShell 用: Set-Location でファイルのディレクトリに移動してからコマンド実行
         ;; run-dir をシングルクォートで囲んで括弧入りパスにも対応
         (ps-quoted-dir (concat "'" (replace-regexp-in-string "'" "''" run-dir t t) "'"))
         (ps-args (concat "-NoExit -Command & { Set-Location " ps-quoted-dir "; " cmd "}")))
    (cond
     (wt
      (cond
       ((eq shell 'cmd)
        (w32-shell-execute
         "open" wt
         (concat "cmd.exe /k cd /d \"" run-dir "\" && " cmd)))
       ((eq shell 'powershell)
        (w32-shell-execute
         "open" wt
         (concat "powershell.exe " ps-args)))))
     (t
      (cond
       ((eq shell 'cmd)
        (w32-shell-execute
         "open" "cmd.exe"
         (concat "/k cd /d \"" run-dir "\" && " cmd)))
       ((eq shell 'powershell)
        (w32-shell-execute
         "open" "powershell.exe"
         ps-args)))))))

(defun my/run-command-cmd-on-current-file (cmd)
  "現在のファイルを引数にして、cmd.exe 経由で外部コマンドを外部ターミナルで実行します。
%f は現在のファイルパスに置き換わります（なければ末尾に追加）。"
  (interactive "s[cmd] 実行する外部コマンド (例: python, agy(Antigravity) -y): ")
  (let ((file (buffer-file-name)))
    (if (not file)
        (user-error "このバッファはファイルに対応していません")
      (when (buffer-modified-p)
        (save-buffer))
      (let* ((quoted-file (shell-quote-argument file))
             (final-cmd (if (string-match-p "%f" cmd)
                            (replace-regexp-in-string "%f" quoted-file cmd t t)
                          (concat cmd " " quoted-file))))
        (my/run-in-external-terminal 'cmd final-cmd)))))

(defun my/ps-quote-argument (file)
  "PowerShell 用にファイルパスをシングルクォートで囲む。
ダブルクォートは w32-shell-execute 経由でWindowsに剥ぎ取られるため
シングルクォートを使う。PowerShell のシングルクォートは括弧等を含む
パスをリテラルとして安全に渡せる。内部にシングルクォートがあれば '' に変換。"
  (concat "'" (replace-regexp-in-string "'" "''" file t t) "'"))

(defun my/run-command-powershell-on-current-file (cmd)
  "現在のファイルを引数にして、PowerShell 経由で外部コマンドを外部ターミナルで実行します。
%f は現在のファイルパスに置き換わります（なければ末尾に追加）。"
  (interactive "s[PowerShell] 実行する外部コマンド (例: python, agy(Antigravity) -y): ")
  (let ((file (buffer-file-name)))
    (if (not file)
        (user-error "このバッファはファイルに対応していません")
      (when (buffer-modified-p)
        (save-buffer))
      (let* ((quoted-file (my/ps-quote-argument file))
             (final-cmd (if (string-match-p "%f" cmd)
                            (replace-regexp-in-string "%f" quoted-file cmd t t)
                          (concat cmd " " quoted-file))))
        (my/run-in-external-terminal 'powershell final-cmd)))))

(defun my/run-agy-cmd-on-current-file (args)
  "現在のファイルを Antigravity (agy.exe) に渡し、cmd.exe 経由で外部ターミナルで実行します。"
  (interactive "s[cmd] Antigravity(agy) の引数 (必要なら入力、例: -y): ")
  (let ((file (buffer-file-name)))
    (if (not file)
        (user-error "このバッファはファイルに対応していません")
      (when (buffer-modified-p)
        (save-buffer))
      (let* ((quoted-file (shell-quote-argument file))
             (cmd (if (string-empty-p args)
                      (concat "agy " quoted-file)
                    (concat "agy " args " " quoted-file))))
        (my/run-in-external-terminal 'cmd cmd)))))

(defun my/run-agy-powershell-on-current-file (args)
  "現在のファイルを Antigravity (agy.exe) に渡し、PowerShell 経由で外部ターミナルで実行します。"
  (interactive "s[PowerShell] Antigravity(agy) の引数 (必要なら入力、例: -y): ")
  (let ((file (buffer-file-name)))
    (if (not file)
        (user-error "このバッファはファイルに対応していません")
      (when (buffer-modified-p)
        (save-buffer))
      (let* ((quoted-file (my/ps-quote-argument file))
             (cmd (if (string-empty-p args)
                      (concat "agy " quoted-file)
                    (concat "agy " args " " quoted-file))))
        (my/run-in-external-terminal 'powershell cmd)))))

;; ファイル操作メニュー
(defhydra hydra-file (:color blue :hint nil)
  "
  === FILE OPERATIONS (M-o F) ===
  [開く・保存]                           [外部アプリで直接開く]
  [_o_] ファイルを開く                   [_e_] 現在のファイルを外部で開く
  [_r_] 最近のファイル                   [_E_] 任意のファイルを外部で開く
  [_s_] 上書き保存                       [_R_] 最近のファイルを外部で開く
  [_m_] m3u8/m3u を検索して再生
  [_k_] バッファを閉じる                 [外部コマンド実行 (現在ファイル)]
                                         [_a_] Antigravity(agy) を cmd で実行
                                         [_A_] Antigravity(agy) を PowerShell で実行
                                         [_x_] コマンドを実行 (cmd, %%%%f=パス)
                                         [_X_] コマンドを実行 (PS, %%%%f=パス)
                                         [その他]
                                         [_d_] WinMerge で差分比較
                                         [_c_] 文字コード指定で開き直す
                                         [_p_] Pandoc で別形式に変換
                                         [_K_] EPUBをKindle (azw/azw3) に変換
  ----------------------------------------------------------------------
  [_q_] 閉じる
"
  ("o" find-file)
  ("r" consult-recent-file)
  ("s" save-buffer)
  ("S" write-file)
  ("k" kill-current-buffer)
  ("e" my-open-current-file-in-windows)
  ("E" my/open-any-file-in-windows)
  ("R" my/open-recent-file-in-windows)
  ("m" my/m3u8-search-and-play)
  ("a" my/run-agy-cmd-on-current-file)
  ("A" my/run-agy-powershell-on-current-file)
  ("x" my/run-command-cmd-on-current-file)
  ("X" my/run-command-powershell-on-current-file)
  ("d" my-compare-with-winmerge)
  ("c" revert-buffer-with-coding-system)
  ("p" my/pandoc-convert-to-format)
  ("K" my/epub-to-kindle-convert)
  ("q" nil :color blue))



;; Obsidian Vault 操作関数（migemo 対応検索含む）
(defun my/obsidian-ripgrep-migemo ()
  "Obsidian Vault 内を migemo（ローマ字）で全文検索します。"
  (interactive)
  (require 'obsidian)
  (let ((orderless-matching-styles '(orderless-migemo)))
    (consult-ripgrep obsidian-directory)))

(defun my/obsidian-find-file-migemo ()
  "Obsidian Vault 内のファイルを migemo でファイル名検索します。"
  (interactive)
  (require 'obsidian)
  (let ((orderless-matching-styles '(orderless-migemo))
        (default-directory obsidian-directory))
    (consult-find obsidian-directory)))

;; Obsidian サブメニュー
(defhydra hydra-obsidian (:color blue :hint nil)
  "
  === OBSIDIAN VAULT (M-o o) ===
  [ファイル操作]                         [検索]
  [_f_] ファイルを開く                   [_s_] Vault内全文検索 (rg)
  [_n_] 新規ノート作成                   [_r_] ローマ字全文検索 (Migemo rg)
  [_i_] リンクを挿入                     [_F_] ファイル名検索 (Migemo)
  [_c_] リンク先ファイルを作成
  ----------------------------------------------------------------------
  [_p_] メインメニューに戻る            [_q_] 閉じる
"
  ("f" (progn (require 'obsidian) (call-interactively #'obsidian-find-file)))
  ("n" (progn (require 'obsidian) (call-interactively #'obsidian-capture)))
  ("i" (progn (require 'obsidian) (call-interactively #'obsidian-insert-link)))
  ("c" (progn (require 'obsidian) (call-interactively #'obsidian-create-missing-file)))
  ("s" (progn (require 'obsidian) (consult-ripgrep obsidian-directory)))
  ("r" my/obsidian-ripgrep-migemo)
  ("F" my/obsidian-find-file-migemo)
  ("p" hydra-launcher/body :color blue)
  ("q" nil :color blue))

;; Markdown サブメニュー（hydra-launcher より先に定義する）
;; ※ markdown-mode は :defer ロードのため、キーを押した瞬間に require して確実に関数を解決する
(defhydra hydra-markdown (:color blue :hint nil)
  "
  === MARKDOWN & TAGS (M-o m) ===
  [装飾・タグ打ち]                       [ナビゲーション・リンク]
  [_1_] 見出し1 (H1)                     [_l_] リンク挿入 (Obsidian風)
  [_2_] 見出し2 (H2)                     [_i_] 画像リンクの挿入
  [_b_] 太字 (Bold)                      [_t_] 目次 (TOC) の生成/更新
  [_k_] 斜体 (Italic)                    [_o_] 見出し検索ジャンプ (consult-outline)
  [_c_] コードブロック (Code)            [_O_] サイドバー開閉 (imenu-list)
  ----------------------------------------------------------------------
  [_p_] メインメニューに戻る            [_q_] 閉じる
"
  ("1" (progn (require 'markdown-mode) (call-interactively #'markdown-insert-header-1)))
  ("2" (progn (require 'markdown-mode) (call-interactively #'markdown-insert-header-2)))
  ("b" (progn (require 'markdown-mode) (call-interactively #'markdown-insert-bold)))
  ("k" (progn (require 'markdown-mode) (call-interactively #'markdown-insert-italic)))
  ("c" (progn (require 'markdown-mode) (call-interactively #'markdown-insert-gfm-code-block)))
  ("l" (progn (require 'markdown-mode) (call-interactively #'markdown-insert-link)))
  ("i" (progn (require 'markdown-mode) (call-interactively #'markdown-insert-image)))
  ("t" (progn (require 'markdown-toc)  (call-interactively #'markdown-toc-generate-or-update)))
  ("o" consult-outline)
  ("O" imenu-list-smart-toggle)
  ("p" hydra-launcher/body :color blue)
  ("q" nil :color blue))

;; Calc サブメニュー（hydra-launcher より先に定義する）
(defhydra hydra-calc (:color blue :hint nil)
  "
  === CALC 電卓 (M-o C) ===
  [起動]                                  [入力モード]
  [_c_] Calc を開く                       [_a_] 代数モード ON  (普通の記法)
  [_m_] Casual メニュー [電卓内: C-o]     [_r_] RPN モード ON  (スタック式)
  ----------------------------------------------------------------------
  [_0_] スタック全消去 (AC)  [直キー: C-u 0 DEL]
  ----------------------------------------------------------------------
  ※ 全設定の初期化（フルリセット）は [C-x * 0] です。
  ----------------------------------------------------------------------
  [_p_] メインメニューに戻る            [_q_] 閉じる
"
  ("c" calc)
  ("m" (progn (calc) (casual-calc-tmenu)))
  ("a" (progn (calc)
              (unless calc-algebraic-mode
                (calc-algebraic-mode nil))
              (message "代数モード（中置記法）に切り替えました")))
  ("r" (progn (calc)
              (when calc-algebraic-mode
                (calc-algebraic-mode nil))
              (message "RPN モード（スタック式）に切り替えました")))
  ("0" (progn (calc)
              (calc-pop-stack (calc-stack-size))))
  ("p" hydra-launcher/body :color blue)
  ("q" nil :color blue))

;; テキスト変換 サブメニュー（hydra-launcher より先に定義する）
(defhydra hydra-text (:color blue :hint nil)
  "
  === テキスト変換 (M-o T) ===
  [並べ替え・重複]                         [ナローイング]
  [_s_] 行を昇順ソート         [_S_] 行を降順ソート   [_n_] 選択範囲に限定 (Narrow)
  [_u_] 重複行を削除 (uniq)                           [_w_] 限定を解除 (Widen)
  ----------------------------------------------------------------------
  [文字種変換（選択範囲）]
  [_z_] 半角 → 全角            [_Z_] 全角 → 半角
  ----------------------------------------------------------------------
  [_b_] メインメニューに戻る   [_q_] 閉じる
"
  ("s" (progn (when (use-region-p) (sort-lines nil (region-beginning) (region-end)))))
  ("S" (progn (when (use-region-p) (sort-lines t   (region-beginning) (region-end)))))
  ("u" (progn (when (use-region-p) (delete-duplicate-lines (region-beginning) (region-end)))))
  ("z" (progn (when (use-region-p) (japanese-hankaku-region (region-beginning) (region-end) t))))
  ("Z" (progn (when (use-region-p) (japanese-zenkaku-region (region-beginning) (region-end)))))
  ("n" my/fancy-narrow-to-region)
  ("w" my/fancy-widen)
  ("b" hydra-launcher/body :color blue)
  ("q" nil :color blue))

;; カラーマーカー サブメニュー（hydra-launcher より先に定義する）
(defhydra hydra-marker (:color blue :hint nil)
  "
  === カラーマーカー (M-o M) ===
  [マーカー操作]                         [ジャンプ]
  [_m_] マーカーをトグル（付ける/外す） [_n_] 次のマーカーへ
  [_k_] マーカーを1つ削除                [_p_] 前のマーカーへ
  [_u_] 全マーカーを削除                [_d_] 定義箇所へジャンプ
  [_c_] Casual メニュー（マーカー上で）
  ----------------------------------------------------------------------
  [_b_] メインメニューに戻る            [_q_] 閉じる
"
  ("m" my/marker-put)
  ("k" my/marker-remove-at-point)
  ("u" my/marker-remove-all)
  ("c" casual-symbol-overlay-tmenu)
  ("n" symbol-overlay-jump-next)
  ("p" symbol-overlay-jump-prev)
  ("d" symbol-overlay-jump-to-definition)
  ("b" hydra-launcher/body :color blue)
  ("q" nil :color blue))

;; メインランチャーメニュー
(defhydra hydra-launcher (:color blue :hint nil)
  "
  === EMACS NAVIGATOR (M-o) ===
  [_e_] Everything (PC内検索)      [_m_] Markdown メニュー
  [_s_] プロジェクト内検索 (rg)    [_o_] Obsidian メニュー
  [_g_] ファイル名検索 (fd)        [_w_] ウィンドウ操作
  [_f_] 最近使ったファイル         [_F_] ファイル操作
  [_r_] ローマ字検索 (Migemo)      [_M_] カラーマーカー
  [_l_] 単語検索ポップアップ       [_L_] カレンダー (calfw)
  [_n_] 新しいウィンドウ (Frame)   [_P_] EPUBリーダー (nov)
  [_z_] Zoxide でファイルを開く    [_d_] 辞書 (Lookup)
  [_O_] moccur (一括編集)
  ---------------------------------------------------------
  [_c_] cmd.exe (conpty)           [_p_] PowerShell (conpty)
  [_C_] 電卓メニュー (Calc)        [_T_] テキスト変換
  [_q_] 閉じる
"
  ("e" consult-locate)
  ("s" my/consult-ripgrep-project)
  ("g" my/consult-fd-project)
  ("G" my/consult-fd-here)
  ("f" consult-recent-file)
  ("r" my/consult-line-migemo)
  ("l" my/consult-line-symbol-at-point)
  ("n" make-frame)
  ("P" my/nov-open-epub)
  ("z" zoxide-find-file)
  ("m" hydra-markdown/body)
  ("o" hydra-obsidian/body)
  ("w" hydra-window/body)
  ("F" hydra-file/body)
  ("M" hydra-marker/body)
  ("c" conpty)
  ("p" conpty-powershell)
  ("L" my/open-calendar)
  ("C" hydra-calc/body)
  ("T" hydra-text/body)
  ("d" lookup)
  ("O" moccur)
  ("q" nil :color blue))

;; --- Hydra をメニューバーに統合 ---
(with-eval-after-load 'hydra
  (let ((menu-map (make-sparse-keymap "Navigator")))
    ;; Navigator メニュー内の項目
    (define-key menu-map [hydra-everything] '(menu-item "Everything PC内検索" consult-locate :keys "M-o e"))
    (define-key menu-map [hydra-fd-project] '(menu-item "ファイル名検索 fd" my/consult-fd-project :keys "M-o g"))
    (define-key menu-map [hydra-fd-here]    '(menu-item "ファイル名検索 fd ここから" my/consult-fd-here :keys "M-o G"))
    (define-key menu-map [separator-1]      '(menu-item "--"))
    (define-key menu-map [hydra-epub]       '(menu-item "EPUB リーダー" my/nov-open-epub :keys "M-o P"))
    (define-key menu-map [hydra-new-frame]  '(menu-item "新しいウィンドウを開く" make-frame :keys "M-o n"))
    (define-key menu-map [separator-2]      '(menu-item "--"))
    (define-key menu-map [hydra-marker]     '(menu-item "カラーマーカー" hydra-marker/body :keys "M-o M"))
    (define-key menu-map [hydra-calc]       '(menu-item "電卓" hydra-calc/body :keys "M-o C"))
    (define-key menu-map [hydra-calendar]   '(menu-item "カレンダー" my/open-calendar :keys "M-o L"))
    (define-key menu-map [hydra-file]       '(menu-item "ファイル操作" hydra-file/body :keys "M-o F"))
    (define-key menu-map [hydra-window]     '(menu-item "ウィンドウ操作" hydra-window/body :keys "M-o w"))
    (define-key menu-map [separator-3]      '(menu-item "--"))
    (define-key menu-map [hydra-obsidian]   '(menu-item "Obsidian メニュー" hydra-obsidian/body :keys "M-o o"))
    (define-key menu-map [hydra-markdown]   '(menu-item "Markdown メニュー" hydra-markdown/body :keys "M-o m"))
    (define-key menu-map [hydra-moccur]     '(menu-item "moccur 一括編集" moccur :keys "M-o O"))
    (define-key menu-map [separator-4]      '(menu-item "--"))
    (define-key menu-map [hydra-main]       '(menu-item "メインランチャーを開く" hydra-launcher/body :keys "M-o"))

    ;; メニューバーの末尾（Help の右）に追加
    (define-key global-map [menu-bar navigator] (cons "Navigator" menu-map))
    ;; Help より後ろに並べるため menu-bar-final-items に登録
    (setq menu-bar-final-items (append menu-bar-final-items '(navigator)))))

;; --- consult ---
(use-package consult
  :bind (("C-f"   . my/consult-line-migemo)
         ("M-y"   . consult-yank-pop)
         ("C-r"   . consult-outline)
         ("C-S-f" . my-consult-ripgrep-with-help)
         ("C-S-g" . my/consult-fd-project)
         ("C-S-h" . my/consult-fd-here)
         ("C-c e" . consult-locate)
         ("<f2>"  . consult-buffer)
         ("<f6>"  . my/open-calendar)
         ("M-o"   . hydra-launcher/body))
  :config
  ;; my/cua-cut-or-prefix 経由では ctl-x-map が正しく引けるが、
  ;; 念のため直接バインドして確実に動作させる
  (define-key ctl-x-map "b" #'consult-buffer)
  (define-key ctl-x-map "k" #'kill-buffer)

  (setq consult-async-split-style 'perl) ; # 区切りで AND 検索（例: -F ミネルヴィニ#株）
  (setq consult-ripgrep-args
        (concat "rg --null --line-buffered --color=never --max-columns=1000 "
                "--path-separator / --smart-case --no-heading "
                "--with-filename --line-number --search-zip "
                "--encoding auto"))
  ;; ripgrep の出力は UTF-8 のため、日本語パスが文字化けしないようにする
  (defun my/consult-ripgrep-utf8 (orig &rest args)
    (let ((coding-system-for-read 'utf-8)
          (coding-system-for-write 'utf-8))
      (apply orig args)))
  (advice-add 'consult-ripgrep :around #'my/consult-ripgrep-utf8)

  (defun my/consult-migemo-regexp (component)
    "COMPONENT を consult 用の Emacs 正規表現に変換する。"
    (condition-case nil
        (if (and (featurep 'migemo)
                 (fboundp 'migemo-get-pattern)
                 (string-match-p "\\`[[:ascii:]]+\\'" component))
            (migemo-get-pattern component)
          (regexp-quote component))
      (error (regexp-quote component))))

  (defun my/consult-migemo-compiler (input type ignore-case)
    "consult 用に Migemo と固定文字列検索を両立する compiler。"
    (let* ((components (consult--split-escaped input))
           (emacs-regexps
            (mapcar #'my/consult-migemo-regexp components))
           (rg-regexps
            (mapcar (lambda (regexp)
                      (consult--convert-regexp regexp type))
                    emacs-regexps)))
      (cons rg-regexps
            (when-let* ((regexps (seq-filter #'consult--valid-regexp-p
                                             emacs-regexps)))
              (apply-partially #'consult--highlight-regexps
                               regexps ignore-case)))))

  (defun my-consult-ripgrep-with-help ()
    "打ち方ヒント付きで consult-ripgrep を起動します。
日本語直接入力は rg の標準検索として扱います。"
    (interactive)
    (let ((consult-async-indicator nil)
          (consult-ripgrep-args
           (concat consult-ripgrep-args " --engine=default")))
      (consult-ripgrep)))

  ;; C-S-f 検索後、結果バッファで wgrep のヒントをミニバッファに表示
  (defun my/wgrep-hint (&rest _)
    "consult-ripgrep 実行後に wgrep の操作ヒントを表示する。"
    (run-with-idle-timer
     0.3 nil
     (lambda ()
       (message "wgrep: C-c C-e で編集モード → C-c C-c で一括保存 / C-c C-k でキャンセル"))))
  (advice-add 'my-consult-ripgrep-with-help :after #'my/wgrep-hint)

  (defun my/consult-fd-project ()
    "現在の project.el ルートを対象に consult-fd を実行します。"
    (interactive)
    (if-let ((project (project-current)))
        (consult-fd (project-root project))
      (call-interactively #'consult-fd)))

  (defun my/consult-fd-here ()
    "現在開いているファイルと同じディレクトリを起点に consult-fd を実行します。
バッファがファイルに紐付いていない場合は default-directory を使います。"
    (interactive)
    (let ((dir (if buffer-file-name
                   (file-name-directory buffer-file-name)
                 default-directory)))
      (consult-fd dir)))

  (defun my/consult-fd-migemo ()
    "Migemo（ローマ字）を使って高速にファイル名検索 (consult-fd) を行います。"
    (interactive)
    (let ((orderless-matching-styles '(orderless-migemo)))
      (consult-fd))))

(use-package embark
  :bind (("C-." . embark-act))
  :config
  (define-key embark-file-map (kbd "e") #'my/open-any-file-in-windows)
  (define-key embark-file-map (kbd "E") #'my/open-any-file-in-windows))
(use-package embark-consult)
(use-package wgrep)

;; =====================================================================
;; EmEditor フィルタ / wgrep わかりやすいラッパー
;; =====================================================================

(defun my/emeditor-filter (&optional engine)
  "EmEditor の〈フィルタ〉機能風：マッチ行だけを表示して直接編集できます。
引数 ENGINE が 'moccur または 'occur の場合はそのエンジンを使用し、
指定がない場合はダイアログや completing-read で選択します。

【手順】
  1. 検索ワードを入力（選択中の文字列・カーソル下の単語が自動入力）
  2. マッチした行だけがフィルタバッファに表示される
  3. フィルタバッファ上で直接テキストを書き換えられる
  4. C-c C-c : 変更を元ファイルに一括反映して保存
  5. q       : フィルタを閉じる（未保存の変更は破棄される）"
  (interactive)
  (let* ((default (if (use-region-p)
                      (buffer-substring-no-properties (region-beginning) (region-end))
                    (thing-at-point 'symbol t)))
         (pattern (read-regexp
                   (format "フィルタ（表示する行 of パターン）%s: "
                           (if default (format " [%s]" default) ""))
                   default))
         ;; color-moccur と moccur-edit がインストールされているかチェック
         (has-moccur (and (locate-library "color-moccur")
                          (locate-library "moccur-edit"))))
    (when (and pattern (not (string-empty-p pattern)))
      (let ((choice
             (cond
              ;; 引数で指定されている場合
              ((eq engine 'moccur) "moccur-edit")
              ((eq engine 'occur) "occur-edit")
              ;; 両方使える場合はメニューを出す
              (has-moccur
               (completing-read "使用する検索・編集エンジン: "
                                '("moccur-edit (Migemo対応)" "occur-edit (標準)")
                                nil t nil nil "moccur-edit (Migemo対応)"))
              ;; occur-edit のみ（標準）
              (t "occur-edit"))))
        (if (string-match-p "moccur-edit" choice)
            ;; moccur-edit を起動
            (progn
              (require 'color-moccur)
              (require 'moccur-edit)
              (moccur pattern)
              (when-let ((moccur-buf (get-buffer "*Moccur*")))
                (pop-to-buffer moccur-buf)
                (moccur-edit-mode-in)
                (message "moccur-edit でフィルタ中: C-c C-c で保存")))
          ;; 標準の occur-edit を起動
          (progn
            (require 'replace) ;; occur/occur-edit 用
            (occur pattern)
            (when-let ((occur-buf (get-buffer "*Occur*")))
              (pop-to-buffer occur-buf)
              (occur-edit-mode)
              (message "occur-edit でフィルタ中: C-c C-c で保存"))))))))

(defun my/wgrep-replace ()
  "EmEditor の〈複数ファイル置換〉風：ripgrep 検索 → 結果を直接編集 → 一括保存。

【手順】
  1. 検索ワードを入力（プロジェクトルート全体が対象）
  2. 検索結果バッファが開く（ファイル名・行番号・内容が一覧表示）
  3. C-c C-p : 編集モードに入る（行を直接書き換えられるようになる）
  4. 検索ワードを置換ワードに書き換える（C-M-% などの通常の置換操作も可）
  5. C-c C-c : 変更を全ファイルに一括保存
  6. C-c C-k : 変更をキャンセル"
  (interactive)
  (message "ripgrep 検索後、C-c C-p で編集モード → C-c C-c で一括保存")
  (call-interactively #'consult-ripgrep))

;; キーバインドの割り当て
(add-hook 'after-init-hook
          (lambda ()
            (global-set-key (kbd "C-c f") #'my/emeditor-filter)
            (global-set-key (kbd "C-c F") #'my/wgrep-replace)))

;; occur-edit-mode のキーをわかりやすく設定
(with-eval-after-load 'replace
  ;; query-replace / replace-string で読み取り専用テキストをスキップして置換できるようにする
  (setq query-replace-skip-read-only t)

  ;; ESC で occur-edit-mode を抜けて read-only の occur-mode に戻る
  ;; （read-only 状態では q が通常通り quit-window として機能する）
  (define-key occur-edit-mode-map (kbd "<escape>")
    (lambda ()
      (interactive)
      (occur-mode)))  ; 編集モードを解除して read-only に戻る

  ;; 保存のヒントをヘッダーに表示するフック
  (add-hook 'occur-edit-mode-hook
            (lambda ()
              (setq header-line-format
                    (propertize
                     "  ✏ フィルタ編集中  |  C-c C-c: 変更を保存  |  ESC: 編集終了(→qで閉じる)"
                     'face '(:background "#1a3a5c" :foreground "#aed6f1" :weight bold)))))

  ;; 読み取り専用の occur-mode に戻ったときのヘッダー表示フック
  (add-hook 'occur-mode-hook
            (lambda ()
              (setq header-line-format
                    (propertize
                     "  🔍 フィルタ表示中  |  e: 編集モードに入る  |  q: 閉じる"
                     'face '(:background "#1a3a5c" :foreground "#aed6f1" :weight bold))))))

;; wgrep の編集モード開始時にヘッダーを表示
(with-eval-after-load 'wgrep
  (add-hook 'wgrep-setup-hook
            (lambda ()
              (setq header-line-format
                    (propertize
                     "  ✏ wgrep 編集中  |  C-c C-c: 変更を全ファイルに保存  |  C-c C-k: キャンセル"
                     'face '(:background "#3a1a1a" :foreground "#f4b8b8" :weight bold))))))

;; --- consult の外部コマンドパス設定（fd / es.exe）---
;; consult-fd・consult-locate ともに consult 本体に含まれるため別途インストール不要
;; use-package :config より確実に適用するため with-eval-after-load で設定する
(with-eval-after-load 'consult
  ;; fd のパスを自動検出: 1) PATH 2) ポータブル bin/ 3) 見つからなければお知らせ
  (let ((fd-exe (or (executable-find "fd")
                    (executable-find "fd.exe")
                    (let ((portable (expand-file-name "bin/fd.exe"
                                                      (expand-file-name ".." user-emacs-directory))))
                      (and (file-exists-p portable) portable)))))
    (if fd-exe
        (setq consult-fd-args (list fd-exe "--color=never" "--full-path"))
      (message "【お知らせ】fd が見つかりません。fd-find をインストールするか portable/bin/ に置いてください。")))

  ;; es.exe のパスを自動検出
  ;; 優先順位: 1) PATH 2) ポータブル bin/ 3) 定番インストール先
  (let ((es-exe (or (executable-find "es.exe")
                    (executable-find "es")
                    (let ((portable (expand-file-name "bin/es.exe"
                                                      (expand-file-name ".." user-emacs-directory))))
                      (and (file-exists-p portable) portable))
                    (cl-find-if #'file-exists-p
                                (list (expand-file-name "Everything/es.exe" (or (getenv "ProgramFiles") "C:/Program Files"))
                                      (expand-file-name "Everything/es.exe" (or (getenv "ProgramFiles(x86)") "C:/Program Files (x86)"))
                                      "C:/tools/Everything/es.exe")))))
    (if es-exe
        (setq consult-locate-args (concat (shell-quote-argument es-exe) " -i -p -r"))
      (message "【お知らせ】es.exe が見つかりません。Everything をインストールするか portable/bin/ に置いてください。"))))


;; --- project.el と fd の連携 ---
(with-eval-after-load 'project
  (defun my/project-files-in-directory (dir)
    "DIR 内のファイルを `fd` を使って高速に取得します。"
    (let* ((fd-exe (or (executable-find "fd")
                       (executable-find "fd.exe")
                       (let ((portable (expand-file-name "bin/fd.exe"
                                                         (expand-file-name ".." user-emacs-directory))))
                         (and (file-exists-p portable) portable))
                       "fd"))           ; フォールバック（エラーメッセージが出る）
           (default-directory dir))
      (process-lines fd-exe "--type" "f" "--strip-cwd-prefix" "--hidden" "--follow" "--exclude" ".git")))

  (defun my/project-files (project)
    "project-files の挙動を `fd` に置き換えます。"
    (my/project-files-in-directory (project-root project)))

  (advice-add 'project-files :override #'my/project-files))

;; --- fd-dired (fd を使った Dired 検索) ---
(use-package fd-dired
  :ensure t
  :config
  ;; Windows環境に合わせた引数の最適化
  (setq fd-dired-pre-args "--color=never --hidden --follow --exclude .git"))

;; modus-themes（gnome2テーマ等の依存対策）
(use-package modus-themes)

;; 右クリックメニューを永続化
(context-menu-mode 1)

;; =====================================================================
;; 11b. IME 連携（tr-ime）
;; ─ Windows IME をEmacsと統合する
;; ─ モードライン表示・ミニバッファ自動OFF・カーソル色変更
;; =====================================================================

(defvar my/use-mozc-modeless t
  "Non-nil なら Windows IME/tr-ime ではなく mozc-modeless を使う。")

;; 背景色の明暗を判定して IME/mozc ON 時のカーソル色を自動選択する
;; tr-ime・mozc-modeless 両方から使うためトップレベルで定義する
(defun my/background-luminance ()
  "現在の背景色の明度を 0.0〜1.0 で返す。"
  (let* ((bg (face-background 'default nil t))
         (rgb (color-name-to-rgb (or bg "black")))
         (r (nth 0 rgb)) (g (nth 1 rgb)) (b (nth 2 rgb)))
    (+ (* 0.299 r) (* 0.587 g) (* 0.114 b))))

(defun my/ime-on-cursor-color ()
  "背景色の明暗から coral / cyan のうち見やすい方を返す。"
  (if (> (my/background-luminance) 0.5)
      "coral"    ; 明るい背景 → coral（暗め）
    "cyan"))     ; 暗い背景   → cyan（明るめ）

(defun my/default-cursor-color ()
  "デフォルトのカーソル色（フェイスの foreground）を返す。"
  (or (face-foreground 'cursor nil t)
      (face-foreground 'default nil t)
      "white"))

(use-package tr-ime
  :if (not my/use-mozc-modeless)
  :config
  (tr-ime-standard-install)
  (setq default-input-method "W32-IME")

  ;; モードラインの IME 状態表示
  ;; [--] = IME OFF  [あ] = IME ON
  ;; モードライン表示は使わない（カーソル色のみで判別）
  (setq-default w32-ime-mode-line-state-indicator "")
  (setq w32-ime-mode-line-state-indicator-list '("" "" ""))
  (w32-ime-initialize)

  ;; tr-ime-standard-install / w32-ime-initialize が
  ;; buffer-file-coding-system のデフォルトを japanese-cp932 系に
  ;; 書き換えてしまうため、ここで UTF-8 に戻す。
  ;; （*scratch* など「ファイルと紐付かないバッファ」が SJIS になる対策）
  (setq-default buffer-file-coding-system 'utf-8)



  ;; IME ON → 自動選択色、OFF → 通常の文字色に戻す
  (add-hook 'w32-ime-on-hook
            (lambda ()
              (set-cursor-color (my/ime-on-cursor-color))
              (setq cursor-type 'box)))
  (add-hook 'w32-ime-off-hook
            (lambda ()
              (set-cursor-color (my/default-cursor-color))
              (setq cursor-type 'box)))

  ;; テーマ切り替え時にも OFF 状態のカーソル色を追従させる
  (add-hook 'enable-theme-functions
            (lambda (_theme)
              (unless current-input-method
                (set-cursor-color (my/default-cursor-color)))))

  ;; ミニバッファ入力時は IME を自動でOFF
  (add-hook 'minibuffer-setup-hook #'deactivate-input-method)

  ;; isearch 中も IME をOFF（検索語は英数字が多いため）
  (add-hook 'isearch-mode-hook
            (lambda () (deactivate-input-method)))

  ;; フレーム作成時（make-frame）にも IME を初期化
  (add-hook 'after-make-frame-functions
            (lambda (f)
              (with-selected-frame f
                (w32-ime-initialize)))))

;; Quail の TAB 補完で *Quail Completions* が開くのを止める。
(with-eval-after-load 'quail
  (define-key quail-translation-keymap (kbd "TAB") nil)
  (define-key quail-translation-keymap (kbd "<tab>") nil))


;; =====================================================================
;; 12. multiple-cursors（マルチカーソル）
;; =====================================================================

(use-package multiple-cursors
  :config
  ;; CUA モードの C-z（矩形選択開始）と競合しないよう mc 操作は C-c m プレフィックスに集約
  ;; よく使う操作だけ単キーにも割り当て
  ;;   C->        … 次の同じ単語にカーソル追加
  ;;   C-<        … 前の同じ単語にカーソル追加
  ;;   C-c m a    … バッファ内の全同一単語にカーソル追加
  ;;   C-c m l    … 選択範囲の各行にカーソル追加
  ;;   C-c m e    … 行末にカーソルを揃えて追加
  :bind
  (("C->"       . mc/mark-next-like-this)        ; 次の同じ単語
   ("C-<"       . mc/mark-previous-like-this)    ; 前の同じ単語
   ("C-c m a"   . mc/mark-all-like-this)         ; 全同一単語
   ("C-c m l"   . mc/edit-lines)                 ; 選択範囲の各行
   ("C-c m e"   . mc/edit-ends-of-lines)))       ; 各行の行末

;; =====================================================================
;; 12b. Zoxide 連携（頻繁に使うディレクトリへの高速移動）
;; =====================================================================
;; 前提: zoxide.exe が PATH または bin/ に配置済みであること
;;   https://github.com/ajeetdsouza/zoxide
;; M-o z で zoxide-find-file を呼び出す（hydra-launcher に登録済み）

(use-package zoxide
  :ensure t)

;; =====================================================================
;; 12b. Markdown モード
;; =====================================================================

(use-package markdown-mode
  :mode (("README\\.md\\'" . gfm-mode)
         ("\\.md\\'"       . markdown-mode))
  :init
  (setq markdown-command "multimarkdown")
  :config
  (setq markdown-header-scaling nil)
  (markdown-reload-extensions))

;; 目次生成プラグイン
(use-package markdown-toc)


;; =====================================================================
;; 12b. Markdown アウトライン機能
;; ─ imenu-list : 右サイドバーに見出し一覧を常時表示
;; ─ outline-minor-mode : 見出し単位で折りたたみ（bicycle で TAB 操作）
;; =====================================================================

;; --- imenu-list（右サイドバーアウトライン） ---
(use-package imenu-list
  :commands imenu-list-smart-toggle
  :config
  (setq imenu-list-position 'right)   ; 右端に表示
  (setq imenu-list-size     0.20)     ; 画面幅の 20%
  (setq imenu-list-focus-after-activation nil) ; 開いてもエディタ側にフォーカスを残す
  (setq imenu-list-auto-resize t))    ; 項目数に合わせて自動リサイズ

;; Markdown を開いたら自動でサイドバーを表示する
;; （markdown-mode は imenu-generic-expression を自前でセットするため
;;   imenu-create-index-function の上書きは不要）
(defun my/imenu-list-open-for-markdown ()
  "markdown-mode バッファを開いたときにアウトラインサイドバーを自動表示します。
howm-mode が有効な場合（howm 経由で開いた md）は表示しません。"
  (when (and (derived-mode-p 'markdown-mode)
             (not (bound-and-true-p howm-mode)))
    (let ((src-win (selected-window)))
      (imenu-list-smart-toggle)
      ;; トグル後もエディタ側にフォーカスを戻す
      ;; selected-window を事前に保存しておくことで
      ;; get-buffer-window が nil を返す競合を回避する
      (when (window-live-p src-win)
        (select-window src-win)))))

;; markdown-mode での自動表示は無効（F4 または M-o m O で手動開閉）
;; (add-hook 'markdown-mode-hook #'my/imenu-list-open-for-markdown)

;; --- outline-minor-mode + bicycle（TAB/S-TAB で折りたたみ） ---
;; bicycle : outline の TAB サイクルを有効にする軽量パッケージ
(use-package bicycle
  :after outline
  :bind (:map outline-minor-mode-map
         ([C-tab]     . bicycle-cycle)          ; C-TAB : このセクションだけ開閉
         ([S-tab]     . bicycle-cycle-global)   ; S-TAB : バッファ全体を一括開閉
         ([backtab]   . bicycle-cycle-global))) ; Shift-TAB（端末互換）

;; markdown-mode で outline-minor-mode を有効化
;; outline-regexp は行頭の # + 空白 にマッチさせる（本文中の ##タグ 等を除外）
(add-hook 'markdown-mode-hook
          (lambda ()
            (setq-local outline-regexp "^#+\\s-")
            (outline-minor-mode 1)))

;; --- キーバインド ---
;;   F4        … imenu-list サイドバーをトグル（既存の Speedbar より便利）
;;   M-o m o   … consult-outline（既存の hydra-markdown の "o" キー）
;;   C-TAB     … 現在の見出しセクションを折りたたみ/展開 (bicycle)
;;   S-TAB     … バッファ全体を一括折りたたみ/展開   (bicycle)
(global-set-key [f4] 'imenu-list-smart-toggle)   ; F4 でサイドバー開閉（Speedbar を置き換え）


;; =====================================================================
;; 13. howm + howm-markdown（Obsidian 互換 Markdown メモ環境）
;; =====================================================================

;; howm-markdown.el を howm より先に読み込む
;; （# をタイトルヘッダーにする等、Markdown 互換設定を事前に行う）
(use-package howm
  :demand t
  :init
  ;; howm-markdown を howm ロード前に適用
  (require 'howm-markdown)

  (setq howm-directory    (expand-file-name "Documents/Obsidian-memo/01_kami"
                                             (or (getenv "USERPROFILE") "~")))
  (setq howm-keyword-file (expand-file-name ".howm-keys" howm-directory))
  ;; ファイル名フォーマット（howm-markdown のデフォルトを上書き）
  (setq howm-file-name-format "%Y%m%d-%H%M%S.md")

  ;; 保存時に1行目の # タイトル をファイル名に反映させる
  (defun my-howm-update-filename-with-title ()
    "保存時に1行目のタイトル # title をファイル名に反映させます。"
    (when (and (or (derived-mode-p 'howm-mode) (derived-mode-p 'markdown-mode))
               (buffer-file-name)
               (file-exists-p (buffer-file-name)))
      (let* ((old-path (buffer-file-name))
             (old-name (file-name-nondirectory old-path))
             (dir (file-name-directory old-path))
             (title nil))
        (save-excursion
          (goto-char (point-min))
          ;; Markdown の # タイトル 形式を抽出
          (when (re-search-forward "^# \(.+\)$" (line-end-position) t)
            (setq title (match-string-no-properties 1))))
        (when (and title
                   (not (string-match-p "\`[[:space:]]*\'" title)))
          (let* ((base-name (file-name-sans-extension old-name))
                 (date-part (if (string-match "_" base-name)
                                (substring base-name 0 (match-beginning 0))
                              base-name))
                 (safe-title (replace-regexp-in-string "[\\/:*?\"<>|]" "" title))
                 (new-name (format "%s_%s.md" date-part safe-title))
                 (new-path (expand-file-name new-name dir)))
            (unless (or (string= old-name new-name)
                        (file-exists-p new-path))
              (rename-file old-path new-path t)
              (set-visited-file-name new-path)
              (set-buffer-modified-p nil)
              (message "タイトル変更に合わせてリネームしました: %s" new-name)))))))

  (add-hook 'howm-after-save-hook 'my-howm-update-filename-with-title)

  :config
  ;; テンプレート（# タイトル 形式・howm-markdown に合わせて変更）
  (setq howm-template-date-format "%Y-%m-%d %H:%M")
  (setq howm-template "# %cursor\n#memo\n[%date]\n\n")

  ;; #タグ を consult-ripgrep で検索する（Obsidian 形式のタグリンク対応）
  (defun my-howm-search-hashtag-at-point ()
    "カーソル位置の #タグ を consult-ripgrep で howm ディレクトリ内検索する。"
    (interactive)
    (let* ((sym (thing-at-point 'symbol t))
           (tag (when sym (concat "#" sym))))
      (if tag
          (consult-ripgrep howm-directory tag)
        (message "カーソルがタグの上にありません"))))

  ;; #タグ をクリック／RET でジャンプできるボタンとして装飾する
  (defun my-howm-make-hashtag-buttons ()
    "バッファ内の #タグ をクリッカブルなボタンにする。"
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "#[[:alnum:]_-]+" nil t)
        (let ((tag (match-string-no-properties 0)))
          (make-button (match-beginning 0) (match-end 0)
                       'action (lambda (_btn)
                                 (consult-ripgrep howm-directory tag))
                       'follow-link t
                       'help-echo (concat "クリックで " tag " を検索"))))))

  (add-hook 'howm-mode-hook 'my-howm-make-hashtag-buttons)

  ;; キーバインド：C-c # でタグ検索
  (define-key howm-mode-map (kbd "C-c #") 'my-howm-search-hashtag-at-point))


;; ④ Cosense × Markdown ハイブリッド・シンタックスハイライト
(defun my-howm-hybrid-syntax-highlighter ()
  "howm 内で Cosense (Scrapbox) と Markdown の両方の記法を強調表示します。"
  (font-lock-add-keywords
   nil `(
         ;; --- Markdown Style ---
         ;; # 見出し, ## 見出し
         ("^\\(#+ \\)\\(.*\\)$" 2 '(:weight bold :foreground "gold") t)
         ;; **太字**
         ("\\*\\*\\([^*]+\\)\\*\\*" 1 '(:weight bold :foreground "white") t)
         ;; `コード`
         ("`\\([^`]+\\)`" 1 '(:foreground "LightSalmon" :background "#333333") t)
         ;; [表示名](URL)
         ("\\[\\([^]]+\\)\\](\\([^)]+\\))" 0 '(:foreground "SkyBlue" :underline t) t)
         ))
  (font-lock-flush))

(defun my-howm-indent-setup ()
  "howm でスペースによる箇条書きと階層化を楽にします。"
  ;; TAB で深く、S-TAB で浅く
  (local-set-key (kbd "TAB") (lambda () (interactive) (save-excursion (beginning-of-line) (insert " "))))
  (local-set-key (kbd "<backtab>") (lambda () (interactive) (save-excursion (beginning-of-line) (when (looking-at " ") (delete-char 1)))))
  ;; 改行時にインデントを引き継ぐ
  (setq-local indent-line-function 'indent-relative-first-indent-point))

(add-hook 'howm-mode-hook 'my-howm-indent-setup)
(add-hook 'howm-mode-hook 'my-howm-hybrid-syntax-highlighter)

;; howm でメモを開いたとき、markdown-mode-hook より遅れて Ilist が開いてしまう
;; タイミング問題への対処：howm-mode-hook で Ilist ウィンドウを閉じる
(add-hook 'howm-mode-hook
          (lambda ()
            (when-let ((ilist-win (get-buffer-window "*Ilist*")))
              (delete-window ilist-win))))

;; ⑤ 画像のインライン表示（iimage-mode）
;; Markdown形式の ![](img/...) も画像として認識するように設定
(add-hook 'howm-mode-hook 'iimage-mode)
(add-hook 'markdown-mode-hook 'iimage-mode)
(with-eval-after-load 'iimage
  (setq iimage-mode-image-regex-alist
        (cons '("!\\[\\](\\([^)]+\\))" . 1)
              iimage-mode-image-regex-alist)))
(setq max-image-size 4.0)

;; ⑥⑦ org-download を howm/markdown で使う
;;     クリップボード貼り付け（C-c v）・ドラッグドロップ両対応
(use-package org-download
  :demand t
  :config

  ;; howm/markdown バッファでの保存先を「メモと同じフォルダの img/」に設定
  (defun my-org-download-dir ()
    "howm または markdown バッファならメモと同じフォルダの img/ を返す。それ以外は nil。"
    (when (and (or (derived-mode-p 'howm-mode) (derived-mode-p 'markdown-mode)) 
               (buffer-file-name))
      (expand-file-name "img" (file-name-directory (buffer-file-name)))))

  (defun my-org-download-set-dir ()
    (when-let ((dir (my-org-download-dir)))
      (setq-local org-download-image-dir dir)))
  (add-hook 'howm-mode-hook 'my-org-download-set-dir)
  (add-hook 'markdown-mode-hook 'my-org-download-set-dir)

  ;; 保存後に挿入するリンク形式を Markdown 形式 ![](...) に変える
  (defun my-org-download-insert-link (filename)
    "org-download が画像を保存した後、Markdown形式でパスを挿入して iimage-mode を更新する。"
    (when (or (derived-mode-p 'howm-mode) (derived-mode-p 'markdown-mode))
      (let ((inhibit-modification-hooks t))
        (save-excursion
          ;; org-download が標準で挿入する [[file:...]] リンクを削除
          (when (re-search-backward "^\\[\\[file:" (line-beginning-position -3) t)
            (delete-region (line-beginning-position) (line-beginning-position 2)))))
      ;; Markdown標準の画像記法で挿入（Obsidian対応）
      (let ((rel-path (file-relative-name filename (file-name-directory (buffer-file-name)))))
        (insert (format "![](%s)\n" rel-path)))
      (when (fboundp 'iimage-mode-buffer)
        (iimage-mode-buffer t))
      (message "画像を保存しました → %s" (file-name-nondirectory filename))))

  (add-hook 'org-download-after-download-hook
            (lambda () (my-org-download-insert-link org-download-last-file)))

  ;; C-c v でクリップボードの画像を貼り付け
  (defun my-howm-paste-image ()
    "クリップボードの画像を img/ に保存して Markdown 形式で挿入します。"
    (interactive)
    (unless (buffer-file-name)
      (user-error "先にメモをファイルとして保存してください"))
    (my-org-download-set-dir)
    (org-download-clipboard))

  (with-eval-after-load 'howm
    (define-key howm-mode-map (kbd "C-c v") 'my-howm-paste-image))
  (with-eval-after-load 'markdown-mode
    (define-key markdown-mode-map (kbd "C-c v") 'my-howm-paste-image))

  ;; ドラッグドロップ対応
  (add-hook 'howm-mode-hook 'org-download-enable))


;; =====================================================================
;; 14. Obsidian との連携
;; =====================================================================

(use-package obsidian
  :config
  (setq obsidian-directory (expand-file-name "Documents/Obsidian-memo"
                                              (or (getenv "USERPROFILE") "~")))
  ;; 新規ノートを常にVaultルートに保存する（フラット運用）
  (setq obsidian-default-directory obsidian-directory)
  ;; WikiLink（[[...]]）を無効化してMarkdown形式 [title](file.md) を使う
  (setq obsidian-wiki-link-style nil)
  (setq obsidian-wiki-link-p     nil)
  ;; キーバインド（use-package :bind で書くと obsidian-mode-map を使えるが、
  ;;   global-set-key のままでも動作に問題はない）
  (global-set-key (kbd "C-c o f") 'obsidian-find-file)
  (global-set-key (kbd "C-c o i") 'obsidian-insert-link)
  (global-set-key (kbd "C-c o c") 'obsidian-create-missing-file)
  (add-hook 'markdown-mode-hook 'obsidian-mode))


;; =====================================================================
;; 15. カレンダー (calfw)
;; =====================================================================

(use-package calfw
  :commands calfw-open-calendar-buffer
  :config
  ;; 見栄えの調整（罫線など）
  (setq calfw-fchar-junction         ?+
        calfw-fchar-vertical-line    ?|
        calfw-fchar-horizontal-line  ?-
        calfw-fchar-left-junction    ?+
        calfw-fchar-right-junction   ?+
        calfw-fchar-top-junction     ?+
        calfw-fchar-bottom-junction  ?+))

(use-package calfw-howm
  :after (calfw howm)
  :config
  ;; howm の予定を表示する際のタイトルを調整
  (setq calfw-howm-schedule-summary-transformer
        (lambda (s) (if (string-match "^\\[\\(.*?\\)\\]" s) (match-string 1 s) s))))

(use-package calfw-org
  :after (calfw org))

;; 祝日設定
(use-package japanese-holidays
  :defer t
  :config
  (setq calendar-holidays
        (append japanese-holidays holiday-local-holidays holiday-other-holidays)))

(defun my/open-calendar ()
  "howm と org の予定を統合してカレンダーを表示します。"
  (interactive)
  (require 'calfw)
  (require 'calfw-howm)
  (require 'calfw-org)
  (calfw-open-calendar-buffer
   :contents-sources
   (list
    (calfw-howm-create-source "howm" "SkyBlue") ; howm の予定
    (calfw-org-create-source  nil "org" "Orange")  ; org の予定
    )))


;; =====================================================================
;; 16. Casual（Transient メニュー UI）
;; ─ Calc を普通の電卓のように使いやすくする
;; ─ Calc 内で C-o でメニューを呼び出す。q または C-g で閉じる
;; =====================================================================

;; Transient を最新版に更新（casual が 0.6.0+ を要求するため）
(setq package-install-upgrade-built-in t)

;; 代数入力モード（algebraic mode）をデフォルトにする
;; → 1 + 2 * 3 RET のような普通の中置記法で入力できる
;; → RPN に戻したい場合は Calc 内で m a をトグル
(setq calc-algebraic-mode t)

(use-package casual
  :after calc
  :bind (:map calc-mode-map
         ("C-o" . casual-calc-tmenu)
         :map calc-alg-map
         ("C-o" . casual-calc-tmenu)))

;; Calc 起動時に操作・リセット方法のヒントをミニバッファに自動表示する
(add-hook 'calc-mode-hook
          (lambda ()
            (run-with-idle-timer
             0.1 nil
             (lambda ()
               (message "💡 Calc: [C-o] メニュー表示  /  [C-u 0 DEL] スタック全消去  /  [C-x * 0] 初期化")))))

;; F7 で Calc を即起動（電卓を呼び出す感覚で）
(global-set-key [f7] #'calc)

;; M-x calculator で表示が切れる問題への対策（ウィンドウ高さを最低4行に拡張）
(add-hook 'calculator-mode-hook
          (lambda ()
            (unless (window-minibuffer-p)
              (let ((target-height 4))
                (when (< (window-height) target-height)
                  (window-resize nil (- target-height (window-height))))))))


;; =====================================================================
;; 17. カラーマーカー（symbol-overlay）
;; ─ カーソル位置の単語を色付きハイライト（複数色・同時使用可）
;; ─ EmEditor のカラーマーカーに近い使い勝手
;; =====================================================================

(use-package symbol-overlay
  :config
  ;; スマートマーカー：選択範囲があればその文字列全体にマーク（バッファ全域）
  ;;                   選択範囲がなければカーソル下の単語に symbol-overlay を使用
  (defvar my/hi-lock-colors
    '("yellow" "LightGreen" "cyan" "pink" "orange" "plum1" "LightSalmon")
    "hi-lock で順番に使う色のリスト。")
  (defvar my/hi-lock-color-index 0
    "次に使う my/hi-lock-colors のインデックス。")

  (defun my/marker-put ()
    "選択範囲があればその文字列をバッファ全域にハイライト。
なければ symbol-overlay-put でカーソル下の単語をハイライト。
同じ文字列に既にマーカーがあればトグルで削除する。"
    (interactive)
    (if (use-region-p)
        (let* ((text (buffer-substring-no-properties
                      (region-beginning) (region-end)))
               (pattern (regexp-quote text)))
          (deactivate-mark)
          ;; hi-lock-mode が無効なら有効化してから参照する
          (unless (bound-and-true-p hi-lock-mode) (hi-lock-mode 1))
          (if (assoc pattern hi-lock-interactive-patterns)
              (hi-lock-unface-buffer pattern)
            ;; face を interned シンボルで登録することで assoc 検索が確実に機能する
            (let* ((color (nth (mod my/hi-lock-color-index
                                    (length my/hi-lock-colors))
                               my/hi-lock-colors))
                   (face-sym (intern (format "my/hi-lock-face-%d"
                                             my/hi-lock-color-index))))
              (setq my/hi-lock-color-index (1+ my/hi-lock-color-index))
              (unless (facep face-sym)
                (make-face face-sym)
                (set-face-attribute face-sym nil
                                    :background color :foreground "black"))
              (hi-lock-face-buffer pattern face-sym))))
      (symbol-overlay-put)))

  (defun my/marker-remove-at-point ()
    "カーソル位置のカラーマーカー（hi-lock または symbol-overlay）を削除します。
カーソル位置にない場合は、ハイライトされているパターンを選択して削除します。"
    (interactive)
    (cond
     ;; 1. 選択範囲がある場合
     ((use-region-p)
      (let* ((text (buffer-substring-no-properties (region-beginning) (region-end)))
             (pattern (regexp-quote text)))
        (deactivate-mark)
        (hi-lock-unface-buffer pattern)))
     ;; 2. カーソル位置に symbol-overlay のハイライトがある場合
     ((and (fboundp 'symbol-overlay-get-symbol)
           (let ((sym (symbol-overlay-get-symbol t)))
             (and sym (symbol-overlay-assoc sym))))
      (symbol-overlay-put))
     ;; 3. カーソル位置の単語が hi-lock でハイライトされている場合
     ((let* ((word (thing-at-point 'word t))
             (pattern (and word (regexp-quote word))))
        (and pattern (assoc pattern hi-lock-interactive-patterns)))
      (let* ((word (thing-at-point 'word t))
             (pattern (regexp-quote word)))
        (hi-lock-unface-buffer pattern)))
     ;; 4. それ以外は、対話的に削除する hi-lock パターンを選択
     (t
      (call-interactively #'hi-lock-unface-buffer))))

  (defun my/marker-remove-all ()
    "hi-lock と symbol-overlay 両方のマーカーをすべて削除する。"
    (interactive)
    (hi-lock-unface-buffer t)
    (setq my/hi-lock-color-index 0)
    (symbol-overlay-remove-all))

  (defun my/toolbar-marker-clear-menu (event)
    "ツールバーをクリックした際に、マーカー削除メニューを表示します。"
    (interactive "e")
    (let ((menu (make-sparse-keymap "マーカー削除")))
      (define-key menu [all]
        '(menu-item "すべてのマーカーを削除" my/marker-remove-all
                    :keys "C-S-u"
                    :help "すべてのカラーマーカーを一括削除します"))
      (define-key menu [one]
        '(menu-item "カーソル位置のマーカーを削除" my/marker-remove-at-point
                    :keys "C-S-k"
                    :help "カーソル位置（または選択範囲）のカラーマーカーを1つ削除します"))
      (popup-menu menu event)))

  ;; マーカーをトグル（同じキーで付け外し）
  (global-set-key (kbd "C-S-m")        #'my/marker-put)
  ;; カーソル位置のマーカーを削除
  (global-set-key (kbd "C-S-k")        #'my/marker-remove-at-point)
  ;; 全マーカーを一括削除
  (global-set-key (kbd "C-S-u")        #'my/marker-remove-all)
  ;; 同じ色のマーカー間をジャンプ
  (global-set-key (kbd "C-S-n")        #'symbol-overlay-jump-next)
  (global-set-key (kbd "C-S-p")        #'symbol-overlay-jump-prev)
  ;; consult-ripgrep で選択後、カーソル下の単語を自動ハイライト
  (defun my/symbol-overlay-after-consult (&rest _)
    "consult 系コマンド実行後にカーソル下の単語を自動ハイライトする。"
    (symbol-overlay-remove-all)
    (symbol-overlay-put))
  (advice-add 'consult-ripgrep          :after #'my/symbol-overlay-after-consult)
  (advice-add 'my/consult-ripgrep-word  :after #'my/symbol-overlay-after-consult)
  (advice-add 'my/consult-ripgrep-project :after #'my/symbol-overlay-after-consult))

;; casual-symbol-overlay：Transient メニューで操作
;; ※ symbol-overlay でハイライトした単語の上にカーソルがある時だけ有効
;; ※ C-o はグローバルで find-file に使用済みのため C-S-m（マーカー上で押す）を割り当て
(use-package casual-symbol-overlay
  :after symbol-overlay
  :bind (:map symbol-overlay-map
         ("C-S-m" . casual-symbol-overlay-tmenu)))


;; =====================================================================
;; 18. EPWING 辞書連携 (Lookup)
;; =====================================================================

(use-package lookup
  :ensure nil
  :load-path "lisp/lookup/lisp"
  :commands (lookup lookup-region lookup-pattern)
  :init
  (setq lookup-enable-splash nil)
  :config
  ;; 🌟 辞書データの場所を指定してください
  ;; 例: '("/path/to/dict1" "/path/to/dict2")
  (setq lookup-search-agents
        '(
          ;; EPWING 辞書の設定テンプレート
          ;; 下記の "C:/path/to/your/epwing/dictionary" を実際のパスに書き換えてください
          (ndeb "C:/path/to/your/epwing/dictionary")
          ))

  ;; eblook.exe のパス（bin フォルダにコピー済み）
  (setq ndeb-program-name (expand-file-name "bin/eblook.exe" 
                                            (expand-file-name ".." user-emacs-directory)))

  ;; 外観の調整
  (setq lookup-display-format 'plain)
  (setq lookup-use-kakasi nil))




;; =====================================================================
;; 19. EPUB リーダー (nov.el)
;; ─ EPUB 電子書籍を Emacs 内で美しく、軽快に閲覧
;; ─ Windows 10/11 標準搭載の tar.exe を使って外部 unzip 依存を完全回避
;; =====================================================================

(use-package nov
  :ensure t
  :mode ("\\.epub\\'" . nov-mode)
  :config
  ;; Windows 対策：Windows 標準の tar.exe を unzip として使う設定
  (when (eq system-type 'windows-nt)
    (setq nov-unzip-program (executable-find "tar")
          nov-unzip-args '("-xC" directory "-f" filename)))

  (defun my/nov-mode-hook ()
    (setq-local line-spacing 0.2)
    (setq-local fill-column 80)
    (visual-line-mode 1))
  (add-hook 'nov-mode-hook #'my/nov-mode-hook))

;; Calibre の ebook-convert を探す（PATH → 環境変数 ProgramFiles 系の順）
(defun my/find-calibre-converter ()
  "ebook-convert.exe のパスを返す。見つからなければ nil。"
  (or (executable-find "ebook-convert")
      (cl-find-if #'file-exists-p
                  (list (expand-file-name "Calibre2/ebook-convert.exe" (or (getenv "ProgramFiles") "C:/Program Files"))
                        (expand-file-name "Calibre2/ebook-convert.exe" (or (getenv "ProgramFiles(x86)") "C:/Program Files (x86)"))))))

(defun my/nov-open-epub ()
  "EPUB ファイルを選択して開きます。"
  (interactive)
  (let ((file (read-file-name "EPUB を選択: " nil nil t nil
                              (lambda (name)
                                (string-match-p "\\.epub\\'" name)))))
    (when (and file (file-exists-p file))
      (find-file file))))

(defun my/nov-open-kindle-on-the-fly (filename)
  "Calibre の ebook-convert を使用して、AZW3/AZW をバックグラウンドで EPUB に変換し、開きます。"
  (interactive "fKindle (AZW3/AZW) ファイルを選択: ")
  (let* ((temp-dir (temporary-file-directory))
         (epub-file (expand-file-name (concat (file-name-base filename) ".epub") temp-dir))
         ;; Calibre のコマンドラインツールを探す（標準のインストールパスも自動探索）
         (converter (my/find-calibre-converter)))
    (cond
     ((not (file-exists-p filename))
      (message "ファイルが存在しません: %s" filename))
     ((not converter)
      (message "【お知らせ】Calibre が見つからないため自動変換できません。手動で EPUB に変換してください。"))
     (t
      (message "Kindle 本から EPUB へ変換中（バックグラウンド処理）...")
      ;; 非同期プロセスで変換（Emacs がフリーズするのを防ぐ）
      (make-process
       :name "kindle-to-epub"
       :buffer nil
       :command (list converter filename epub-file)
       :sentinel (lambda (process event)
                   (when (string-match-p "finished" event)
                     (if (file-exists-p epub-file)
                         (progn
                           (message "変換完了！書籍を開きます。")
                           (find-file epub-file))
                       (message "エラー: 変換後のファイルが見つかりません。")))))))))

;; .azw と .azw3 ファイルを C-x C-f で開いたときにも自動でこの関数にルーティングする
(defun my/nov-open-kindle-on-the-fly-auto ()
  "auto-mode-alist 経由で AZW/AZW3 ファイルを開くためのラッパー。"
  (let ((filename (buffer-file-name)))
    (when filename
      (my/nov-open-kindle-on-the-fly filename))))

(dolist (pattern '("\\.azw3\\'" "\\.azw\\'"))
  (add-to-list 'auto-mode-alist (cons pattern #'my/nov-open-kindle-on-the-fly-auto)))


;; =====================================================================
;; 20. ドキュメントビューア ＆ 変換 (xdoc2txt / Pandoc 連携)
;; ─ Word / PDF / Excel 等からテキストを抽出して Emacs 内で直接閲覧
;; ─ 現在のバッファを Pandoc で別形式 (docx, epub, pdf 等) に高速変換
;; =====================================================================

(defun my/document-text-view ()
  "xdoc2txt または pandoc を使って、Word/PDF/Excel などのテキストを抽出し、Emacs 内で直接閲覧します。"
  (interactive)
  (let* ((filename (buffer-file-name))
         (xdoc2txt (executable-find "xdoc2txt.exe"))
         (pandoc (executable-find "pandoc"))
         (ext (and filename (file-name-extension filename))))
    (when filename
      ;; 一旦バッファをクリアし、プレーンテキスト表示にする
      (setq-local buffer-file-name nil)        ; 保存ダイアログが出ないよう nil に設定
      (let ((inhibit-read-only t))
        (erase-buffer)
        (message "テキストを抽出中...")
        (cond
         ;; 1. xdoc2txt があれば最優先で使用 (PDF, docx, xlsx, pptx 等を高速網羅)
         (xdoc2txt
          (call-process xdoc2txt nil t nil "-8" filename))
         ;; 2. xdoc2txt がなく、pandoc があり、対象が docx などの場合
         ((and pandoc (member ext '("docx" "epub" "html" "md" "rst")))
          (call-process pandoc nil t nil "-t" "plain" filename))
         ;; 3. どちらもない場合
         (t
          (insert "エラー: xdoc2txt または pandoc が見つかりません。\n"
                  "バイナリファイルのテキスト抽出機能を利用するには、いずれかの実行ファイルを PATH に追加してください。")))
        (goto-char (point-min))
        (set-buffer-modified-p nil)
        (view-mode 1)
        (message "テキスト抽出完了 (閲覧モード)")))))

;; 各種ドキュメントファイルを C-x C-f で開いたときに自動でテキスト閲覧モードにする
(dolist (pattern '("\\.docx\\'" "\\.pdf\\'" "\\.xlsx\\'" "\\.pptx\\'"
                   "\\.doc\\'" "\\.xls\\'" "\\.ppt\\'"))
  (add-to-list 'auto-mode-alist (cons pattern #'my/document-text-view)))

(defun my/pandoc-convert-to-format (out-format)
  "現在のバッファ（Markdown等）を Pandoc を使って別フォーマットに変換します。"
  (interactive
   (list (completing-read "出力フォーマット: "
                          '("epub" "html" "pdf" "docx" "odt" "org" "markdown" "plain"))))
  (let* ((filename (buffer-file-name))
         (pandoc (executable-find "pandoc")))
    (cond
     ((not filename)
      (message "エラー: バッファをファイルとして保存してから実行してください。"))
     ((not pandoc)
      (message "エラー: pandoc が見つかりません。PATH に追加してください。"))
     (t
      (let* ((out-file (concat (file-name-sans-extension filename) "." out-format))
             (exit-code (call-process pandoc nil nil nil
                                      filename "-o" out-file)))
        (if (= exit-code 0)
            (message "変換完了！出力先: %s" (file-name-nondirectory out-file))
          (message "エラー: 変換に失敗しました。")))))))

(defun my/epub-to-kindle-convert (filename &optional format)
  "EPUB ファイルを AZW または AZW3 形式に変換します。"
  (interactive
   (let* ((current-file (buffer-file-name))
          (default-file (and current-file
                             (string-match-p "\\.epub\\'" current-file)
                             current-file))
          (file (read-file-name "EPUB ファイルを選択: " nil default-file t nil
                                (lambda (name)
                                  (or (file-directory-p name)
                                      (string-match-p "\\.epub\\'" name)))))
          (fmt (completing-read "出力形式: " '("azw3" "azw" "both") nil t "both")))
     (list file fmt)))
  (let* ((converter (my/find-calibre-converter))
         (format (or format "both")))
    (cond
     ((not (file-exists-p filename))
      (message "ファイルが存在しません: %s" filename))
     ((not converter)
      (message "【お知らせ】Calibre (ebook-convert.exe) が見つかりませんでした。インストールパスを確認してください。"))
     (t
      (let ((formats (if (string= format "both") '("azw" "azw3") (list format))))
        (dolist (fmt formats)
          (let* ((out-file (concat (file-name-sans-extension filename) "." fmt))
                 (out-name (file-name-nondirectory out-file)))
            (message "%s へ変換中（バックグラウンド処理）..." out-name)
            (make-process
             :name (concat "epub-to-" fmt)
             :buffer nil
             :command (list converter filename out-file)
             :sentinel (lambda (process event)
                         (when (string-match-p "finished" event)
                           (message "変換完了！出力先: %s" out-file)))))))))))


;; =====================================================================
;; 21. CSV モード
;; =====================================================================
;; rainbow-csv は MELPA 未登録のため、csv-mode 標準のフィールド番号表示で代用
;; （モードラインに現在の列番号が表示される）

(use-package csv-mode
  :ensure t
  :mode ("\.csv\'" "\.tsv\'")
  :config
  (setq csv-separators '("," "\t")))  ; カンマとタブ両対応


;; =====================================================================
;; 21b. Mozc 日本語入力（モードレス）
;; =====================================================================
;; 前提:
;;   - Windows に Google 日本語入力がインストールされていること
;;   - mozc_emacs_helper.exe を bin/ に配置済み
;;     (https://github.com/smzht/mozc_emacs_helper の ver_2.31.5810.100)

(use-package mozc
  :ensure t
  :if my/use-mozc-modeless
  :config
  (setq default-input-method "japanese-mozc")
  (setq mozc-helper-program-name
        (let ((portable (expand-file-name "bin/mozc_emacs_helper.exe"
                                           (expand-file-name ".." user-emacs-directory))))
          (if (file-exists-p portable)
              portable
            "mozc_emacs_helper")))


  ;; Windows の mozc では SendKey 応答が direct モードなら hiragana に切り替える
  (advice-add 'mozc-session-execute-command :filter-return
              (lambda (output)
                (when (and output
                           (eq (mozc-protobuf-get output 'output 'mode) 'direct))
                  (mozc-session-sendkey '(Hankaku/Zenkaku)))
                output))

  ;; SJIS など UTF-8 以外のバッファでも mozc_emacs_helper との通信が
  ;; 文字化けしないよう、通信時のコーディングシステムを UTF-8 に固定する。
  ;; （カレントバッファのエンコーディングに process-coding-system が
  ;;   引っ張られて文字化けする問題への対処）
  ;; ※ "Wrong response from the Server" エラーが出るため一時的に無効化
  ;; (advice-add 'mozc-session-execute-command :around
  ;;             (lambda (orig &rest args)
  ;;               (let ((coding-system-for-read  'utf-8)
  ;;                     (coding-system-for-write 'utf-8))
  ;;                 (apply orig args))))
  )

(use-package mozc-modeless
  :ensure t
  :if my/use-mozc-modeless
  :after mozc
  :config
  (global-mozc-modeless-mode 1)

  ;; C-\ で mozc-mode を手動 ON/OFF できるようにする
  ;; OFF 時は deactivate の抑制をスキップする
  (defvar my/mozc-manual-off nil
    "Non-nil なら mozc-mode を手動で OFF にしている状態。")

  (defun my/mozc-toggle ()
    "mozc-mode を手動でトグルする。"
    (interactive)
    (if my/mozc-manual-off
        ;; OFF → ON
        (progn
          (setq my/mozc-manual-off nil)
          (activate-input-method "japanese-mozc")
          (message "Mozc ON"))
      ;; ON → OFF
      (progn
        (setq my/mozc-manual-off t)
        (deactivate-input-method)
        (message "Mozc OFF"))))

  (global-set-key (kbd "C-\\") #'my/mozc-toggle)

  ;; M-<kanji>（Alt+漢字／Alt+E/J）は IME 切り替え時の誤爆イベントなので無視する
  (global-set-key (kbd "M-<kanji>") #'ignore)
  (with-eval-after-load 'mozc-modeless
    (define-key mozc-modeless-mode-map (kbd "M-<kanji>") #'ignore))

  ;; deactivate-input-method が mozc-mode をバッファローカルに OFF に
  ;; してしまうのを防ぐ（手動OFFのときは抑制しない）
  (defun my/mozc-modeless-inhibit-deactivate (&rest _args)
    (when (and (bound-and-true-p mozc-modeless-mode)
               (not my/mozc-manual-off))
      (setq current-input-method "japanese-mozc")))
  (advice-add 'deactivate-input-method :after
              #'my/mozc-modeless-inhibit-deactivate)

)


;; =====================================================================
;; 22. gptel（LLM チャットクライアント）
;; =====================================================================

(use-package gptel
  :ensure t
  :config


  (require 'gptel-gemini)
  (require 'gptel-openai)
  (require 'gptel-openai-extras)

  (defun my/gptel-api-key (envvar &optional auth-host)
    "Return a function that reads an API key from ENVVAR or auth-source."
    (lambda ()
      (or (getenv envvar)
          (when auth-host
            (ignore-errors
              (gptel-api-key-from-auth-source auth-host)))
          (user-error "Set %s or add an auth-source entry for %s"
                      envvar (or auth-host "the active gptel backend")))))

  ;; Windows 付属 curl.exe が Schannel の SEC_E_NO_CREDENTIALS で失敗する
  ;; 環境があるため、ポータブル同梱 curl を優先する。
  (let ((portable-curl (expand-file-name "../bin/curl.exe" user-emacs-directory)))
    (when (file-executable-p portable-curl)
      (setq gptel-use-curl portable-curl
            ;; 同梱 curl は CA bundle が無い環境で証明書検証に失敗する。
            ;; cacert.pem を導入できたら --cacert 指定に置き換える。
            gptel-curl-extra-args '("--insecure"))))

  ;; curl プロセスのコーディングシステムを UTF-8 に固定（日本語環境でのCP932化を防ぐ）
  (add-to-list 'process-coding-system-alist
               '("curl" . (utf-8 . utf-8)))

  ;; 🌟 LLMが自律的にツールを呼び出せるようにする設定
  (setq gptel-use-tools t)


  ;; ── デフォルトモデル（OpenAI GPT-4o）──────────────────────────────
  (setq gptel-model   'gpt-4o
        gptel-api-key (my/gptel-api-key "OPENAI_API_KEY" "api.openai.com"))

  ;; ── xAI Grok ──────────────────────────────────────────────────────
  (gptel-make-xai "xAI"
    :key    (my/gptel-api-key "XAI_API_KEY" "api.x.ai")
    :stream t)

  ;; ── Google Gemini（AI Studio）─────────────────────────────────────
  (gptel-make-gemini "Gemini"
    :key    (my/gptel-api-key "GEMINI_API_KEY" "generativelanguage.googleapis.com")
    :models '(gemini-2.5-flash
              gemini-2.5-pro
              gemini-2.0-flash
              gemini-1.5-flash
              gemini-1.5-pro)
    :stream t)

  ;; ── OpenRouter ────────────────────────────────────────────────────
  ;; OpenRouter 経由で多数のモデルにアクセスできます。
  ;; :models に使いたいモデルを列挙してください。
  (gptel-make-openai "OpenRouter"
    :host    "openrouter.ai"
    :endpoint "/api/v1/chat/completions"
    :key     (my/gptel-api-key "OPENROUTER_API_KEY" "openrouter.ai")
    :models  '(anthropic/claude-opus-4
               anthropic/claude-sonnet-4
               meta-llama/llama-3.3-70b-instruct
               google/gemini-2.5-flash
               google/gemini-2.5-pro
               deepseek/deepseek-r1)
    :stream  t)

  ;; ── キーバインド ──────────────────────────────────────────────────
  ;; 🌟 CUA モード対応：C-RET は CUA の矩形選択に使われるため回避
  ;;    C-c RET  → gptel-send  （CUA と非競合）
  ;;    C-c g g  → gptel       （チャットバッファを開く）
  ;;    C-c g m  → gptel-menu  （モデル・パラメータ切り替え）
  :bind
  (("C-c RET" . gptel-send)   ; 選択範囲／カーソル位置を送信
   ("C-c g g" . gptel)        ; gptel バッファを開く（旧 C-c C-<return>）
   ("C-c g m" . gptel-menu))) ; モデル・パラメータ切り替えメニュー


;; =====================================================================
;; 23. GhostText 連携（ブラウザ入力欄の編集）
;; =====================================================================
;; ブラウザの GhostText 拡張機能と連携し、Emacs でブラウザ上のテキストエリアを
;; リアルタイム編集できるようにします。
;; =====================================================================

(use-package atomic-chrome
  :ensure t
  :config
  ;; デフォルトのメジャーモード（多くの入力欄がMarkdownであるため）
  (setq atomic-chrome-default-major-mode 'markdown-mode)
  ;; 同一フレーム内の新しいウィンドウでバッファを開く
  (setq atomic-chrome-buffer-open-style 'window)
  ;; ドメインとメジャーモードの対応マップ
  (setq atomic-chrome-url-major-mode-alist
        '(("github\\.com" . gfm-mode)
          ("qiita\\.com" . markdown-mode)
          ("zenn\\.dev" . markdown-mode)
          ("backlog\\.jp" . markdown-mode)
          ("slack\\.com" . markdown-mode)))

  ;; 🌟 WebSocket切断時にバッファが自動キルされるのを防ぐアドバイス
  (defun my/atomic-chrome-on-close-no-kill (socket)
    "WebSocket切断時にバッファをキルせず、編集中のデータを保護します。"
    (let ((buffer (atomic-chrome-get-buffer-by-socket socket)))
      (when buffer
        (remhash buffer atomic-chrome-buffer-table)
        (ignore-errors (websocket-close socket)) ; 明示的にソケットをクローズしてブラウザ側の青枠を消す
        (message "GhostText: 接続が切断されました。編集内容を保護するためバッファを維持します。"))))
  (advice-add 'atomic-chrome-on-close :override #'my/atomic-chrome-on-close-no-kill)

  ;; 連携用 WebSocket サーバーを起動
  (atomic-chrome-start-server))


;; =====================================================================
;; GUIカスタマイズ設定（custom-set-variables）は、init.elの先頭で
;; custom.el を読み込むことで一本化されています。
;; =====================================================================

;; =====================================================================
;; 右クリックメニュー（EmEditor 風コンテキストメニュー）
;; =====================================================================
;; Emacs 28 以降の context-menu-mode を使用します。
;; =====================================================================

(require 'url-util)
(require 'japan-util)  ; 全角↔半角・ひらがな↔カタカナ変換

;; 右クリックメニューを有効化
(when (fboundp 'context-menu-mode)
  (context-menu-mode 1))

;; --- 補助関数 ---

(defun my/ctx-google-search (click)
  "選択範囲またはクリック位置の単語を Google で検索します。"
  (interactive "e")
  (let ((phrase (if (use-region-p)
                    (buffer-substring-no-properties (region-beginning) (region-end))
                  (save-excursion
                    (mouse-set-point click)
                    (thing-at-point 'word t)))))
    (if (and phrase (not (string-empty-p phrase)))
        (browse-url (concat "https://www.google.com/search?q=" (url-hexify-string phrase)))
      (message "検索するテキストが見つかりません"))))

(defun my/ctx-url-encode-region (start end)
  "選択範囲を URL エンコードします。"
  (interactive "r")
  (let ((encoded (url-hexify-string (buffer-substring-no-properties start end))))
    (delete-region start end)
    (insert encoded)))

(defun my/ctx-url-decode-region (start end)
  "選択範囲を URL デコードします。"
  (interactive "r")
  (let ((decoded (url-unhex-string (buffer-substring-no-properties start end))))
    (delete-region start end)
    (insert decoded)))

(defun my/ctx-copy-file-path ()
  "編集中ファイルのフルパスをクリップボードにコピーします。"
  (interactive)
  (if buffer-file-name
      (let ((path (file-truename buffer-file-name)))
        (kill-new path)
        (message "パスをコピーしました: %s" path))
    (message "このバッファはファイルに関連付けられていません")))

(defun my/ctx-copy-file-name ()
  "編集中ファイルのファイル名（拡張子付き）のみをクリップボードにコピーします。"
  (interactive)
  (if buffer-file-name
      (let ((name (file-name-nondirectory buffer-file-name)))
        (kill-new name)
        (message "ファイル名をコピーしました: %s" name))
    (message "このバッファはファイルに関連付けられていません")))

(defun my/ctx-copy-dir-path ()
  "編集中ファイルのディレクトリパスをクリップボードにコピーします。"
  (interactive)
  (if buffer-file-name
      (let ((dir (file-name-directory (file-truename buffer-file-name))))
        (kill-new dir)
        (message "フォルダパスをコピーしました: %s" dir))
    (message "このバッファはファイルに関連付けられていません")))

(defun my/ctx-open-folder ()
  "ファイルの保存先フォルダをエクスプローラーで開きます。"
  (interactive)
  (if buffer-file-name
      (let ((dir (file-name-directory (file-truename buffer-file-name))))
        (w32-shell-execute "explore" (subst-char-in-string ?/ ?\\ dir))
        (message "エクスプローラーで開きました: %s" dir))
    (message "このバッファはファイルに関連付けられていません")))

(defun my/ctx-calc-onthespot ()
  "xyzzy の calc-onthespot 風: 選択範囲または直前の数式を計算して置き換えます。

動作:
  ・テキストを選択している場合 → 選択範囲全体を数式として評価
  ・選択がない場合             → カーソル直前の数式を自動検出して評価

検出できる文字: 数字 / + - * / ^ ( ) . , % ! スペース タブ"
  (interactive)
  (let* ((start (if (use-region-p)
                    (region-beginning)
                  ;; カーソル直前の数式を自動検出（xyzzy 風）
                  (save-excursion
                    (skip-chars-backward "-0-9.+*/^(), \t%!")
                    (point))))
         (end   (if (use-region-p) (region-end) (point)))
         (expr  (string-trim (buffer-substring-no-properties start end))))
    (cond
     ((string-empty-p expr)
      (message "数式が見つかりません（カーソル直前に数式を入力してください）"))
     (t
      (let ((result (condition-case err
                        (calc-eval expr)
                      (error (format "[ERROR: %s]" (error-message-string err))))))
        (if (string-prefix-p "[" result)
            (message "計算エラー: %s  (式: %s)" result expr)
          (when (use-region-p) (deactivate-mark))
          (delete-region start end)
          (insert result)
          (message "%s = %s" expr result)))))))

(defun my/ctx-insert-line-prefix (prefix)
  "選択範囲の各行、または現在の行の行頭に指定のプレフィックスを挿入します。"
  (let ((start (if (use-region-p) (region-beginning) (line-beginning-position)))
        (end (if (use-region-p) (region-end) (line-end-position))))
    (save-excursion
      (goto-char start)
      (beginning-of-line)
      (let ((end-marker (copy-marker end)))
        (while (< (point) end-marker)
          (insert prefix)
          (forward-line 1))
        (set-marker end-marker nil)))))

(defun my/ctx-delete-line-prefix (regexp)
  "選択範囲の各行、または現在の行の行頭にある指定の正規表現パターンを削除します。"
  (let ((start (if (use-region-p) (region-beginning) (line-beginning-position)))
        (end (if (use-region-p) (region-end) (line-end-position))))
    (save-excursion
      (goto-char start)
      (beginning-of-line)
      (let ((end-marker (copy-marker end)))
        (while (< (point) end-marker)
          (if (looking-at regexp)
              (replace-match ""))
          (forward-line 1))
        (set-marker end-marker nil)))))

(defun my/ctx-add-quote ()
  "選択範囲の各行または現在の行 of 行頭に '>' を挿入します。"
  (interactive)
  (my/ctx-insert-line-prefix "> ")
  (message "行頭に引用記号 (>) を挿入しました"))

(defun my/ctx-remove-quote ()
  "選択範囲の各行または現在の行 of 行頭の '>' を削除します。"
  (interactive)
  (my/ctx-delete-line-prefix "^> ?")
  (message "行頭の引用記号 (>) を削除しました"))

;; --- コンテキストメニュー本体 ---

(defun my/emeditor-context-menu (menu click)
  "EmEditor 風の右クリックメニュー項目を追加します。"

  ;; ── 区切り線 ──
  (define-key-after menu [my-sep-top] menu-bar-separator)

  ;; ── バッファ内検索（C-c l / popup-search 相当）──
  (define-key-after menu [my-popup-search]
    `(menu-item "バッファ内検索 (popup-search)"
                (lambda (e) (interactive "e")
                  (unless (use-region-p) (mouse-set-point e))
                  (my/consult-line-symbol-at-point))
                :keys "C-c l"
                :help "選択範囲またはカーソル下の単語でバッファ内をライブ検索します"))

  ;; ── EmEditor フィルタ風・wgrep ──
  (define-key-after menu [my-filter]
    `(menu-item "フィルタ: マッチ行だけ表示・編集"
                (lambda (_e) (interactive "e") (my/emeditor-filter))
                :keys "C-c f"
                :help "EmEditorのフィルタ風：検索ワードにマッチした行だけを表示し、直接編集できます"))

  (define-key-after menu [my-wgrep]
    `(menu-item "複数ファイル一括置換 (wgrep)"
                (lambda (_e) (interactive "e") (my/wgrep-replace))
                :keys "C-c F"
                :help "ripgrep で複数ファイルを検索し、結果を直接編集して一括保存します"))

  ;; ── Google 検索 ──
  (define-key-after menu [my-google-search]
    `(menu-item "Googleで検索"
                (lambda (e) (interactive "e") (my/ctx-google-search e))
                :help "選択範囲またはカーソル下の単語をGoogleで検索します"))

  ;; ── 変換サブメニュー ──
  (let ((conv-map (make-sparse-keymap "変換")))
    ;; 大文字/小文字
    (define-key conv-map [upcase]
      '(menu-item "大文字にする (ABC)" upcase-region
                  :help "選択範囲を大文字にします"
                  :enable (use-region-p)))
    (define-key conv-map [downcase]
      '(menu-item "小文字にする (abc)" downcase-region
                  :help "選択範囲を小文字にします"
                  :enable (use-region-p)))
    (define-key conv-map [capitalize]
      '(menu-item "先頭文字を大文字に (Abc)" capitalize-region
                  :help "各単語の先頭を大文字にします"
                  :enable (use-region-p)))
    (define-key conv-map [conv-sep1] menu-bar-separator)
    ;; エンコード
    (define-key conv-map [url-encode]
      '(menu-item "URLエンコード" my/ctx-url-encode-region
                  :help "選択範囲をURLエンコードします"
                  :enable (use-region-p)))
    (define-key conv-map [url-decode]
      '(menu-item "URLデコード" my/ctx-url-decode-region
                  :help "選択範囲をURLデコードします"
                  :enable (use-region-p)))
    (define-key conv-map [conv-sep2] menu-bar-separator)
    (define-key conv-map [base64-encode]
      '(menu-item "Base64エンコード" base64-encode-region
                  :help "選択範囲をBase64エンコードします"
                  :enable (use-region-p)))
    (define-key conv-map [base64-decode]
      '(menu-item "Base64デコード" base64-decode-region
                  :help "選択範囲をBase64デコードします"
                  :enable (use-region-p)))
    (define-key conv-map [conv-sep3] menu-bar-separator)
    ;; 全角・半角・ひらがな・カタカナ変換（japan-util.el 標準関数）
    (define-key conv-map [zenkaku-to-hankaku]
      '(menu-item "全角→半角" japanese-hankaku-region
                  :help "選択範囲の全角文字を半角に変換します"
                  :enable (use-region-p)))
    (define-key conv-map [hankaku-to-zenkaku]
      '(menu-item "半角→全角" japanese-zenkaku-region
                  :help "選択範囲の半角文字を全角に変換します"
                  :enable (use-region-p)))
    (define-key conv-map [conv-sep4] menu-bar-separator)
    (define-key conv-map [hira-to-kata]
      '(menu-item "ひらがな→カタカナ" japanese-katakana-region
                  :help "選択範囲のひらがなをカタカナに変換します"
                  :enable (use-region-p)))
    (define-key conv-map [kata-to-hira]
      '(menu-item "カタカナ→ひらがな" japanese-hiragana-region
                  :help "選択範囲のカタカナをひらがなに変換します"
                  :enable (use-region-p)))
    (define-key conv-map [conv-sep5] menu-bar-separator)
    ;; 数式計算（xyzzy の calc-onthespot 風：選択なしでもカーソル前を自動検出）
    (define-key conv-map [calc-spot]
      '(menu-item "数式をその場で計算" my/ctx-calc-onthespot
                  :keys "C-c ="
                  :help "選択範囲 or カーソル直前の数式を自動検出して計算・置換します"))
    (define-key conv-map [conv-sep6] menu-bar-separator)
    ;; TAB→スペース変換（選択範囲があれば選択内のみ、なければバッファ全体）
    (define-key conv-map [tab-to-space]
      '(menu-item "TAB→スペースに変換 (untabify)"
                  (lambda () (interactive)
                    (if (use-region-p)
                        (untabify (region-beginning) (region-end))
                      (untabify (point-min) (point-max)))
                    (message "TABをスペースに変換しました"))
                  :help "TAB文字をスペースに変換します（選択範囲 or バッファ全体）"))
    ;; スペース→TAB変換（逆変換）
    (define-key conv-map [space-to-tab]
      '(menu-item "スペース→TABに変換 (tabify)"
                  (lambda () (interactive)
                    (if (use-region-p)
                        (tabify (region-beginning) (region-end))
                      (tabify (point-min) (point-max)))
                    (message "スペースをTABに変換しました"))
                  :help "スペースをTAB文字に変換します（選択範囲 or バッファ全体）"))
    (define-key-after menu [my-conv-submenu]
      `(menu-item "変換" ,conv-map :help "大文字小文字やエンコードの変換")))

  ;; ── 行操作サブメニュー ──
  (let ((line-map (make-sparse-keymap "行操作")))
    (define-key line-map [sort-asc]
      '(menu-item "行を昇順でソート" sort-lines
                  :help "選択範囲の行を昇順にソートします"
                  :enable (use-region-p)))
    (define-key line-map [sort-desc]
      '(menu-item "行を降順でソート"
                  (lambda () (interactive)
                    (sort-lines t (region-beginning) (region-end)))
                  :help "選択範囲の行を降順にソートします"
                  :enable (use-region-p)))
    (define-key line-map [dedup]
      '(menu-item "重複行の削除" delete-duplicate-lines
                  :help "選択範囲内の重複した行を削除します"
                  :enable (use-region-p)))
    (define-key line-map [line-sep1] menu-bar-separator)
    (define-key line-map [add-quote]
      '(menu-item "行頭に引用記号 [> ] を挿入" my/ctx-add-quote
                  :help "選択範囲の各行、または現在の行の行頭に引用記号を追加します"))
    (define-key line-map [remove-quote]
      '(menu-item "行頭の引用記号 [>] を削除" my/ctx-remove-quote
                  :help "選択範囲の各行、または現在の行の行頭にある引用記号を削除します"))
    (define-key-after menu [my-line-submenu]
      `(menu-item "行操作" ,line-map :help "ソートや重複行削除")))

  ;; ── ファイル/フォルダサブメニュー ──
  (let ((file-map (make-sparse-keymap "ファイル/フォルダ")))
    (define-key file-map [copy-fullpath]
      '(menu-item "フルパスをコピー" my/ctx-copy-file-path
                  :help "ファイルの絶対パスをクリップボードにコピーします"
                  :enable buffer-file-name))
    (define-key file-map [copy-filename]
      '(menu-item "ファイル名のみコピー" my/ctx-copy-file-name
                  :help "ファイル名（拡張子付き）をコピーします"
                  :enable buffer-file-name))
    (define-key file-map [copy-dirpath]
      '(menu-item "フォルダパスをコピー" my/ctx-copy-dir-path
                  :help "ファイルが存在するフォルダのパスをコピーします"
                  :enable buffer-file-name))
    (define-key file-map [file-sep1] menu-bar-separator)
    (define-key file-map [open-explorer]
      '(menu-item "エクスプローラーで開く" my/ctx-open-folder
                  :help "ファイルの保存先フォルダをエクスプローラーで開きます"
                  :enable buffer-file-name))
    (define-key file-map [open-assoc]
      '(menu-item "関連付けアプリで開く" my-open-current-file-in-windows
                  :help "Windowsの関連付けプログラムでファイルを開きます"
                  :enable buffer-file-name))
    (define-key file-map [file-sep2] menu-bar-separator)
    (define-key file-map [winmerge]
      '(menu-item "WinMergeで差分比較" my-compare-with-winmerge
                  :help "WinMergeで現在のファイルを差分比較します"
                  :enable buffer-file-name))
    (define-key-after menu [my-file-submenu]
      `(menu-item "ファイル/フォルダ" ,file-map :help "パスのコピーやエクスプローラー起動")))

  menu)

;; フックに登録
;; t（末尾追加）を指定することで、標準の Cut/Copy/Paste が上に、
;; カスタム項目が下に来るようにする
(add-hook 'context-menu-functions #'my/emeditor-context-menu t)

;; *scratch* など「ファイルと紐付かないバッファ」が
;; tr-ime / set-language-environment の影響で SJIS (japanese-cp932)
;; になってしまう問題への最終対策。
;; 全初期化が終わった後に強制的に UTF-8 へ戻す。
(add-hook 'after-init-hook
          (lambda ()
            (setq-default buffer-file-coding-system 'utf-8)
            (with-current-buffer "*scratch*"
              (set-buffer-file-coding-system 'utf-8 t))))

;; =====================================================================
;; 19. リアルタイム置換 (visual-replace)
;; ─ 標準の M-% (通常置換) や C-M-% (正規表現置換) の挙動を置き換え、
;;   入力中にリアルタイムでバッファ上にプレビューを表示します
;; =====================================================================
(use-package visual-replace
  :ensure t
  :config
  (visual-replace-global-mode 1)
  ;; ※注意: ここでデフォルトを t にすると選択範囲が無視されるため、nilのままにします。
  ;; 選択範囲がない場合の「全体置換」はスマートコマンド側で制御します。
  (setq visual-replace-default-to-full-scope nil) 

  ;; スマート通常置換コマンド
  (defun my/visual-replace-smart ()
    "選択範囲があれば選択範囲、なければバッファ全体を対象にして通常置換を起動します。"
    (interactive)
    (let ((visual-replace-default-to-full-scope (not (use-region-p))))
      (call-interactively 'visual-replace)))

  ;; スマート正規表現置換コマンド
  (defun my/visual-replace-regexp-smart ()
    "選択範囲があれば選択範囲、なければバッファ全体を対象にして正規表現置換を起動します。"
    (interactive)
    (let ((visual-replace-default-to-full-scope (not (use-region-p)))
          (visual-replace-defaults-hook '(visual-replace-toggle-regexp)))
      (call-interactively 'visual-replace)))

  ;; ポップアップメニューを定義（選択範囲の有無で表示を切り替え）
  (defun my/visual-replace-menu ()
    "置換オプションのポップアップメニューを表示します。"
    (interactive)
    (let ((map (make-sparse-keymap "置換オプション")))
      (if (use-region-p)
          ;; 選択範囲がある場合（逆順に登録）
          (progn
            (define-key map [regexp-region]
              '(menu-item "正規表現置換 (選択範囲のみ)"
                          (lambda () (interactive)
                            (let ((visual-replace-defaults-hook '(visual-replace-toggle-regexp))
                                  (visual-replace-default-to-full-scope nil))
                              (call-interactively 'visual-replace)))
                          :keys "C-M-%"))
            (define-key map [normal-region]
              '(menu-item "通常置換 (選択範囲のみ)"
                          (lambda () (interactive)
                            (let ((visual-replace-defaults-hook nil)
                                  (visual-replace-default-to-full-scope nil))
                              (call-interactively 'visual-replace)))
                          :keys "M-%"))
            (define-key map [normal-full-forced]
              '(menu-item "通常置換 (バッファ全体に強制)"
                          (lambda () (interactive)
                            (let ((visual-replace-defaults-hook nil)
                                  (visual-replace-default-to-full-scope t))
                              (deactivate-mark)
                              (call-interactively 'visual-replace))))))
        ;; 選択範囲がない場合（逆順に登録）
        (progn
          (define-key map [regexp-from]
            '(menu-item "正規表現置換 (カーソル位置から)"
                        (lambda () (interactive)
                          (let ((visual-replace-defaults-hook '(visual-replace-toggle-regexp))
                                (visual-replace-default-to-full-scope nil))
                            (call-interactively 'visual-replace)))))
          (define-key map [regexp-full]
            '(menu-item "正規表現置換 (バッファ全体)"
                        (lambda () (interactive)
                          (let ((visual-replace-defaults-hook '(visual-replace-toggle-regexp))
                                (visual-replace-default-to-full-scope t))
                            (call-interactively 'visual-replace)))
                        :keys "C-M-%"))
          (define-key map [normal-from]
            '(menu-item "通常置換 (カーソル位置から)"
                        (lambda () (interactive)
                          (let ((visual-replace-defaults-hook nil)
                                (visual-replace-default-to-full-scope nil))
                            (call-interactively 'visual-replace)))))
          (define-key map [normal-full]
            '(menu-item "通常置換 (バッファ全体)"
                        (lambda () (interactive)
                          (let ((visual-replace-defaults-hook nil)
                                (visual-replace-default-to-full-scope t))
                            (call-interactively 'visual-replace)))
                        :keys "M-%"))))
      (popup-menu map)))

  ;; キーバインドの設定
  (global-set-key (kbd "M-%") 'my/visual-replace-smart)
  (global-set-key (kbd "C-M-%") 'my/visual-replace-regexp-smart)

  ;; 置換入力中に C-r または M-r で正規表現の ON/OFF をトグル可能にする
  (define-key visual-replace-mode-map (kbd "C-r") 'visual-replace-toggle-regexp)
  (define-key visual-replace-mode-map (kbd "M-r") 'visual-replace-toggle-regexp)

  ;; Isearch中から文字列を引き継いで起動するキーバインド
  (define-key isearch-mode-map (kbd "M-%") 'visual-replace-from-isearch)

  ;; ミニバッファ（consult-line等）に入力された文字列を引き継いで起動するコマンド
  (defun my/visual-replace-from-minibuffer ()
    "ミニバッファに入力されている文字列を検索パターンとして、元のバッファで `visual-replace` を起動します。"
    (interactive)
    (let ((query (minibuffer-contents-no-properties)))
      (abort-recursive-edit)
      (run-at-time 0 nil
                   (lambda (q)
                     (let ((visual-replace-defaults-hook nil))
                       (visual-replace q)))
                   query)))

  ;; ミニバッファ入力中に M-% で置換へ移行
  (define-key minibuffer-local-map (kbd "M-%") 'my/visual-replace-from-minibuffer))

;; =====================================================================
;; 20. 範囲外のグレーアウト（ソフトナローイング：部分編集）
;; ─ 選択範囲に限定（Narrow）した際、範囲外を非表示にするのではなく、
;;   グレーアウト（影付き）で表示したまま編集・移動制限をかけます
;; =====================================================================
(defvar-local my/narrow-overlays nil
  "ナローイング範囲外をグレーアウトするためのオーバーレイリスト。")

(defvar-local my/narrow-bounds nil
  "現在のナローイング範囲 (start . end)")

(defun my/fancy-narrow-keep-inside ()
  "カーソルがナローイング範囲外に出た場合、範囲内に戻します。"
  (when my/narrow-bounds
    (let ((l (car my/narrow-bounds))
          (r (cdr my/narrow-bounds)))
      (cond
       ((< (point) l) (goto-char l))
       ((> (point) r) (goto-char r))))))

;; マイナーモードとして定義（モードラインに Narrow と表示させるため）
(define-minor-mode my/fancy-narrow-mode
  "範囲外をグレーアウトして編集制限をかける部分編集（ソフトナローイング）モード。"
  :init-value nil
  :lighter " Narrow"
  :keymap nil
  (if my/fancy-narrow-mode
      (add-hook 'post-command-hook 'my/fancy-narrow-keep-inside nil t)
    (remove-hook 'post-command-hook 'my/fancy-narrow-keep-inside t)
    (my/fancy-widen-overlays)))

(defun my/fancy-widen-overlays ()
  "グレーアウトオーバーレイと範囲設定をクリアします。"
  (mapc #'delete-overlay my/narrow-overlays)
  (setq my/narrow-overlays nil)
  (setq my/narrow-bounds nil))

(defun my/fancy-narrow-to-region (start end)
  "選択範囲を限定し、範囲外をグレーアウトして読み取り専用にします。"
  (interactive "r")
  (my/fancy-widen) ; すでにアクティブなら一度解除
  (let ((l (min start end))
        (r (max start end)))
    ;; 範囲外（上）のオーバーレイを作成
    (when (> l (point-min))
      (let ((ov (make-overlay (point-min) l)))
        (overlay-put ov 'face 'shadow)
        (overlay-put ov 'read-only t)
        (overlay-put ov 'evaporate t)
        (push ov my/narrow-overlays)))
    ;; 範囲外（下）のオーバーレイを作成
    (when (< r (point-max))
      (let ((ov (make-overlay r (point-max))))
        (overlay-put ov 'face 'shadow)
        (overlay-put ov 'read-only t)
        (overlay-put ov 'evaporate t)
        (push ov my/narrow-overlays)))
    (setq-local my/narrow-bounds (cons l r))
    (my/fancy-narrow-mode 1)
    (message "部分編集モード: %d 行〜 %d 行 (解除は M-o T w)" 
             (line-number-at-pos l) (line-number-at-pos r))))

(defun my/fancy-widen ()
  "グレーアウトと編集制限を解除し、全体表示に戻します。"
  (interactive)
  (my/fancy-narrow-mode 0)
  (message "部分編集モードを解除しました。"))


;; =====================================================================
;; 18. dmacro (Dynamic Macro) — 繰り返しの自動マクロ実行
;; =====================================================================

(use-package dmacro
  :ensure t
  :init
  ;; 繰り返しを再現するキーを C-t に設定
  (setq dmacro-key (kbd "C-t"))
  :config
  (global-dmacro-mode 1))


