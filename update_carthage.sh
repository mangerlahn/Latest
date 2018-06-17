#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo "Carthage version required (e.g. 0.11)"
    exit 1
fi

curl -OlL "https://github.com/Carthage/Carthage/releases/download/$1/Carthage.pkg"
sudo installer -pkg "Carthage.pkg" -target /
rm "Carthage.pkg"