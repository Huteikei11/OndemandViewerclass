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
bundle exec rake db:create RAILS_ENV=production
echo "Running migrations..."
bundle exec rake db:migrate RAILS_ENV=production
echo "Loading seed data..."
bundle exec rake db:seed RAILS_ENV=production

echo "=== Build Complete ==="
