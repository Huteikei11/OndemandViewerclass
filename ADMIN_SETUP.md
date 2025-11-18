# 管理者アカウントの作成・設定方法

## 🔐 管理者権限について

管理者は以下の権限を持ちます：
- ✅ **全ての動画**を閲覧・編集・削除できる
- ✅ **全ての動画**の分析画面を閲覧できる
- ✅ **プライベート動画**も含め全動画にアクセス可能
- ✅ **他のユーザーが作成した動画**も管理可能

---

## 📋 管理者アカウントの作成方法

### 方法1: 既存ユーザーを管理者にする

#### ローカル環境（開発環境）

```bash
# Railsコンソールを起動
rails console

# メールアドレスでユーザーを検索して管理者に設定
user = User.find_by(email: "admin@example.com")
user.update(admin: true)
exit
```

#### Render（本番環境）

1. **Renderダッシュボード** → あなたのサービス → **Shell** タブ

2. 以下のコマンドを実行:

```bash
cd /opt/render/project/src
RAILS_ENV=production bundle exec rails console

# メールアドレスでユーザーを検索して管理者に設定
user = User.find_by(email: "admin@example.com")
user.update(admin: true)
exit
```

---

### 方法2: 新規管理者アカウントを作成

#### ローカル環境

```bash
rails console

# 新しい管理者ユーザーを作成
User.create!(
  email: "admin@example.com",
  password: "SecurePassword123!",
  password_confirmation: "SecurePassword123!",
  name: "管理者",
  admin: true
)
exit
```

#### Render（本番環境）

```bash
cd /opt/render/project/src
RAILS_ENV=production bundle exec rails console

User.create!(
  email: "admin@example.com",
  password: "SecurePassword123!",
  password_confirmation: "SecurePassword123!",
  name: "管理者",
  admin: true
)
exit
```

---

## 🔍 管理者の確認

### 管理者かどうかチェック

```ruby
rails console

# ユーザーを取得
user = User.find_by(email: "admin@example.com")

# 管理者かどうか確認
user.admin?
# => true (管理者の場合)
# => false (一般ユーザーの場合)

exit
```

### 全管理者の一覧を表示

```ruby
rails console

# 管理者一覧
User.where(admin: true).pluck(:email, :name)

exit
```

---

## ⚙️ 管理者権限の解除

```ruby
rails console

user = User.find_by(email: "admin@example.com")
user.update(admin: false)

exit
```

---

## 📝 使用例

### 例1: 既存ユーザー（user@example.com）を管理者にする

**ローカル:**
```bash
rails console
User.find_by(email: "user@example.com").update(admin: true)
exit
```

**Render:**
```bash
cd /opt/render/project/src
RAILS_ENV=production bundle exec rails console
User.find_by(email: "user@example.com").update(admin: true)
exit
```

### 例2: 複数の管理者を一括作成

```ruby
rails console

admins = [
  { email: "admin1@example.com", name: "管理者1", password: "Password123!" },
  { email: "admin2@example.com", name: "管理者2", password: "Password456!" }
]

admins.each do |admin_data|
  User.create!(
    email: admin_data[:email],
    name: admin_data[:name],
    password: admin_data[:password],
    password_confirmation: admin_data[:password],
    admin: true
  )
end

exit
```

---

## 🎯 簡単コピペ用コマンド

### ローカル開発環境で管理者を作成:

```bash
rails console
User.find_by(email: "あなたのメールアドレス").update(admin: true)
exit
```

### Render本番環境で管理者を作成:

```bash
cd /opt/render/project/src
RAILS_ENV=production bundle exec rails console
User.find_by(email: "あなたのメールアドレス").update(admin: true)
exit
```

---

## ⚠️ セキュリティ注意事項

1. **管理者パスワードは強力なものを使用**してください
2. **管理者権限は信頼できるユーザーのみ**に付与してください
3. **定期的に管理者リストを確認**してください
4. 不要になった管理者権限は速やかに解除してください

---

## 🔄 デプロイ時の注意

本番環境（Render）にデプロイした後、必ず以下を実行してください：

1. マイグレーションの実行は自動で行われます
2. Shellから管理者を手動で設定する必要があります

```bash
# Renderの Shell で実行
cd /opt/render/project/src
RAILS_ENV=production bundle exec rails console
User.find_by(email: "あなたのメールアドレス").update(admin: true)
exit
```
