#!/bin/bash

git init
git config user.name "Corey Farwell"
git config user.email "coreyf@rwell.org"

git remote add upstream "https://$GH_TOKEN@github.com/rust-fuzz/book.git"
git fetch upstream
git reset upstream/gh-pages

touch .

git add -A .
git commit -m "rebuild pages at ${rev}"
git push -q upstream HEAD:gh-pages > /dev/null 2>&1
