#!/bin/bash

for archive in "$@"; do
    case "$archive" in
        *.bz2)                     bunzip2 "$archive"                                ;;
        *.gz)                      gunzip "$archive"                                 ;;
        *.rar)                     rar x "$archive"                                  ;;
        *.rpm)                     rpm2cpio "$archive" | cpio -idmv                  ;;
        *.tar)                     tar xf "$archive"                                 ;;
        *.tar.xz)                  tar xJf "$archive"                                ;;
        *.tbz2 | *.tar.bz2)        tar xjf "$archive"                                ;;
        *.tgz | *.tar.gz)          tar xzf "$archive"                                ;;
        *.Z)                       uncompress "$archive"                             ;;
        *.zip | *.sublime-package) unzip "$archive"                                  ;;
        *)                         echo "[ERROR] Unknown extension '${archive##*.}'" ;;
    esac
done
