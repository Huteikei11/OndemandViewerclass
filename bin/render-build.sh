#!/usr/bin/env bash
# exit on error
set -o errexit

echo "=== Starting Render Build ==="

# 必要なディレクトリを作成
echo "Creating directories..."
mkdir -p storage
mkdir -p tmp/pids
mkdir -p log

echo "Installing dependencies..."
bundle install

echo "Precompiling assets..."
bundle exec rake assets:precompile
bundle exec rake assets:clean

echo "Setting up database..."
# データベースファイルが存在しない場合のみセットアップ
if [ ! -f storage/production.sqlite3 ]; then
  echo "Creating new database..."
  bundle exec rake db:create RAILS_ENV=production
  echo "Loading schema..."
  bundle exec rake db:schema:load RAILS_ENV=production
  echo "Loading seed data..."
  bundle exec rake db:seed RAILS_ENV=production
else
  echo "Database exists, running migrations..."
  bundle exec rake db:migrate RAILS_ENV=production
fi

# 常にマイグレーションを確実に実行（新しいカラムなどが追加されている場合に対応）
echo "Ensuring all migrations are applied..."
bundle exec rake db:migrate RAILS_ENV=production || true

echo "=== Build Complete ==="
