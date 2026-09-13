@echo off
setlocal

:: バッチファイルがある場所を基準ルートにする
set "PORTABLE_ROOT=%~dp0"

:: 1. Emacsのホームディレクトリ（~）をこのフォルダに固定し、PCの個人フォルダを汚さない
set "HOME=%PORTABLE_ROOT%"

:: 2. 独自に作った bin フォルダ（ripgrepやcmigemo等が入っている場所）にパスを通す
set "PATH=%PORTABLE_ROOT%bin;%PATH%"

:: 3. Emacsを起動する
set LANG=ja_JP.UTF-8
set TERM=xterm-256color
set COLORTERM=truecolor

:: 起動直前に Windows 本体の IME を確実に OFF (英数直接入力) にする
python -c "import ctypes; u=ctypes.windll.user32; i=ctypes.windll.imm32; h=i.ImmGetDefaultIMEWnd(u.GetForegroundWindow()); u.SendMessageW(h, 0x0283, 6, 0) if h else None" 2>nul

"%PORTABLE_ROOT%emacs\bin\emacs.exe" -nw %*

endlocal
