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
start "" "%PORTABLE_ROOT%emacs\bin\runemacs.exe" %*

endlocal
