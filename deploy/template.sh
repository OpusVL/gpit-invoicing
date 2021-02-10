#!/bin/bash

source .env

function render_template() {
  eval "echo \"$(cat $1)\""
}

for f in ./*.tpl; do
  echo "Templating ${f:0:-4}"
  render_template "$f" > "${f:0:-4}"
done