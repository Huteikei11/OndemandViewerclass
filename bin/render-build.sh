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
# データベースのセットアップ
set +e  # 一時的にエラーで停止しないようにする
bundle exec rake db:create RAILS_ENV=production
CREATE_EXIT=$?
set -e  # エラーで停止を再開

echo "Database create exit code: $CREATE_EXIT"
echo "Running schema load..."
bundle exec rake db:schema:load RAILS_ENV=production
echo "Schema load completed!"

echo "Verifying tables..."
bundle exec rails runner "puts 'Tables: ' + ActiveRecord::Base.connection.tables.join(', ')" RAILS_ENV=production

echo "Loading seed data..."
bundle exec rake db:seed RAILS_ENV=production || echo "Seed failed or no seeds to load"

echo "=== Build Complete ==="
