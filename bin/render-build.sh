#!/usr/bin/env bash
# exit on error
set -o errexit

# 必要なディレクトリを作成
mkdir -p storage
mkdir -p tmp/pids
mkdir -p log

bundle install
bundle exec rake assets:precompile
bundle exec rake assets:clean

# データベースのセットアップ
bundle exec rake db:create
bundle exec rake db:migrate
bundle exec rake db:seed
