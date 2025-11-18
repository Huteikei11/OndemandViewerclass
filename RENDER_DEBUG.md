# Render デバッグガイド

## 500エラーのトラブルシューティング

### 📋 Renderのログで確認すべき情報

Renderダッシュボード → あなたのサービス → **Logs** タブで以下を探してください：

1. **エラーの詳細メッセージ**
   ```
   Error: ...
   ```

2. **スタックトレース**
   ```
   app/controllers/...
   ```

3. **データベース関連のエラー**
   ```
   ActiveRecord::...
   SQLite3::...
   ```

---

## よくある500エラーの原因と対処法

### 1. ❌ ディレクトリが存在しない
**エラー例:**
```
Errno::ENOENT: No such file or directory @ rb_sysopen - storage/production.sqlite3
```

**対処法:** すでに修正済み（render-build.shでディレクトリ作成）

---

### 2. ❌ RAILS_MASTER_KEYが間違っている
**エラー例:**
```
ActiveSupport::MessageEncryptor::InvalidMessage
ArgumentError: key must be 32 bytes
```

**対処法:**
1. Renderダッシュボード → Environment → RAILS_MASTER_KEY
2. 値を確認: `04125fda31e69638982c17a50855ecd4`
3. 間違っている場合は修正して再デプロイ

---

### 3. ❌ データベースマイグレーションエラー
**エラー例:**
```
ActiveRecord::PendingMigrationError
```

**対処法:**
Renderのシェルで手動実行:
```bash
bundle exec rake db:migrate
```

---

### 4. ❌ ホスト名が許可されていない
**エラー例:**
```
Blocked host: your-app.onrender.com
```

**対処法:** すでに修正済み（production.rbで許可）

---

### 5. ❌ Active Storageの設定エラー
**エラー例:**
```
ActiveStorage::FileNotFoundError
```

**対処法:** すでに修正済み（storage.ymlにproduction追加）

---

## 🔧 デバッグモードを有効にする

より詳細なエラー情報を表示するには:

### Renderの環境変数に追加:
```
DEBUG_MODE=true
```

これにより、本番環境でも詳細なエラーページが表示されます。

⚠️ **重要:** 問題解決後は必ず削除してください！

---

## 🩺 手動でデバッグする方法

### Renderのシェルにアクセス:

1. Renderダッシュボード → サービス選択
2. **Shell** タブをクリック
3. 以下のコマンドを実行:

```bash
# Railsコンソールを起動
bundle exec rails console

# データベース接続確認
ActiveRecord::Base.connection.execute("SELECT 1")

# ユーザー数を確認
User.count

# ストレージパスを確認
Rails.root.join('storage')
```

---

## 📊 ログの確認コマンド

Renderのシェルで:

```bash
# 本番ログを確認
tail -f log/production.log

# エラーだけを抽出
grep -i error log/production.log

# 最新100行を表示
tail -n 100 log/production.log
```

---

## 🚨 緊急時の対処

### すべてをリセットしてやり直す:

1. **ディスクを削除**
   - Renderダッシュボード → Disks → Delete

2. **新しいディスクを作成**
   ```
   Name: ondemand-viewer-storage
   Mount Path: /opt/render/project/src/storage
   Size: 1 GB
   ```

3. **Manual Deploy**
   - "Clear build cache & deploy" を実行

---

## 📝 情報収集チェックリスト

エラー報告時に以下の情報を提供してください:

- [ ] Renderのログに表示されているエラーメッセージ全文
- [ ] スタックトレース（どのファイルのどの行でエラーか）
- [ ] 環境変数が正しく設定されているか（RAILS_MASTER_KEY等）
- [ ] ディスクが正しくマウントされているか
- [ ] デプロイログの最後の部分（Deploy succeeded or failed）

---

## 💡 次にチェックすべきこと

1. **Renderのログ全体をコピー**して内容を確認
2. 特に以下のキーワードを探す:
   - `Error:`
   - `FATAL:`
   - `failed:`
   - `ActiveRecord::`
   - `Errno::`
   
3. 見つかったエラーメッセージを共有してください
