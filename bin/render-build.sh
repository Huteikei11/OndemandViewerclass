#!/usr/bin/env bash
# exit on error
set -o errexit

bundle install
bundle exec rake assets:precompile
bundle exec rake assets:clean

# データベースのセットアップ（初回のみ）
if [ ! -f storage/production.sqlite3 ]; then
  bundle exec rake db:create
  bundle exec rake db:schema:load
  bundle exec rake db:seed
else
  bundle exec rake db:migrate
fi
