# Render デプロイ後の緊急対処法

## 🚨 admin カラムエラーの修正

### エラー内容
```
ActionView::Template::Error (undefined local variable or method 'admin' for an instance of User)
```

### 原因
本番環境のデータベースに`admin`カラムが追加されていません。

---

## ✅ 解決方法

### 1. Renderの Shell でマイグレーションを実行

1. **Renderダッシュボード** → あなたのサービス → **Shell** タブ

2. 以下のコマンドを実行:

```bash
cd /opt/render/project/src
RAILS_ENV=production bundle exec rake db:migrate
```

3. 成功メッセージを確認:
```
== 20251118132823 AddAdminToUsers: migrating ==
-- add_column(:users, :admin, :boolean, {:default=>false, :null=>false})
== 20251118132823 AddAdminToUsers: migrated ==
```

4. サービスを再起動（自動で再起動されない場合）:
   - Renderダッシュボード → **Manual Deploy** → **Deploy latest commit**

---

## 🔍 マイグレーション確認

以下のコマンドでマイグレーション状態を確認できます:

```bash
cd /opt/render/project/src
RAILS_ENV=production bundle exec rake db:migrate:status
```

`admin`カラムのマイグレーションが`up`状態になっているか確認してください。

---

## 📝 今後のデプロイ

次回以降のデプロイでは、ビルドスクリプトが自動的にマイグレーションを実行します。

ビルドログで以下を確認:
```
Database exists, running migrations...
== 20251118132823 AddAdminToUsers: migrating ==
...
```

---

## ⚠️ トラブルシューティング

### マイグレーションが失敗する場合

1. データベースファイルの確認:
```bash
ls -la storage/production.sqlite3
```

2. マイグレーションをロールバック:
```bash
RAILS_ENV=production bundle exec rake db:rollback
```

3. 再度マイグレーション:
```bash
RAILS_ENV=production bundle exec rake db:migrate
```

### それでもエラーが続く場合

データベースをリセット（⚠️ 全データが削除されます）:

```bash
cd /opt/render/project/src
rm storage/production.sqlite3
RAILS_ENV=production bundle exec rake db:schema:load
```

---

## 🎯 修正完了の確認

1. ブラウザで `https://ondemand-viewer.onrender.com` にアクセス
2. エラーが表示されず、動画一覧が表示されることを確認
3. ログインして動作確認

修正完了です！
