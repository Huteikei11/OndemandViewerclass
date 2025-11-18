# Render.com デプロイ手順

## 📋 事前準備

### 1. RAILS_MASTER_KEYの確認
```bash
cat config/master.key
```
**値:** `04125fda31e69638982c17a50855ecd4`

この値は後でRenderの環境変数に設定します。

---

## 🚀 Renderでのデプロイ手順

### ステップ1: GitHubにプッシュ

```bash
cd /home/anada/OndemandViewerclass
git add .
git commit -m "Add Render deployment configuration"
git push origin TimeLine  # または main
```

### ステップ2: Render.comでアカウント作成

1. https://render.com にアクセス
2. "Get Started for Free" をクリック
3. GitHubアカウントで認証

### ステップ3: 新しいWeb Serviceを作成

1. ダッシュボードで **"New +"** → **"Web Service"** をクリック
2. **"Build and deploy from a Git repository"** を選択
3. GitHubリポジトリを接続:
   - "Configure account" で権限を付与
   - `OndemandViewerclass` リポジトリを選択
   - "Connect" をクリック

### ステップ4: サービス設定

以下の設定を入力:

#### 基本設定
- **Name:** `ondemand-viewer` (任意の名前)
- **Region:** `Singapore` (日本に最も近い)
- **Branch:** `TimeLine` (または `main`)
- **Runtime:** `Ruby`

#### ビルド＆デプロイ設定
- **Build Command:** 
  ```
  ./bin/render-build.sh
  ```

- **Start Command:**
  ```
  bundle exec puma -C config/puma.rb
  ```

#### インスタンスタイプ
- **Free** を選択（月750時間無料、非アクティブ時スリープ）

### ステップ5: 環境変数の設定

"Environment Variables" セクションで以下を追加:

| Key | Value |
|-----|-------|
| `RAILS_MASTER_KEY` | `04125fda31e69638982c17a50855ecd4` |
| `RAILS_ENV` | `production` |
| `RAILS_LOG_TO_STDOUT` | `enabled` |
| `RAILS_SERVE_STATIC_FILES` | `enabled` |

⚠️ **重要:** `RAILS_MASTER_KEY` は上記の値を正確にコピーしてください

### ステップ6: ディスク（永続ストレージ）の追加

1. "Disk" セクションまでスクロール
2. **"Add Disk"** をクリック
3. 以下を設定:
   - **Name:** `ondemand-viewer-storage`
   - **Mount Path:** `/opt/render/project/src/storage`
   - **Size:** `1 GB` (無料)
4. "Save" をクリック

### ステップ7: デプロイ実行

1. **"Create Web Service"** をクリック
2. デプロイが自動的に開始されます（5〜10分程度）
3. ログを確認:
   ```
   Building...
   Installing dependencies...
   Precompiling assets...
   Deploy succeeded 🎉
   ```

---

## ✅ デプロイ完了後

### アプリケーションにアクセス

デプロイが完了すると、以下のURLでアクセス可能:
```
https://ondemand-viewer.onrender.com
```

### 初回セットアップ（ユーザー作成）

1. ブラウザでアプリにアクセス
2. "Sign up" をクリック
3. メールアドレスとパスワードでアカウント作成
4. 動画をアップロードして試用

---

## 🔧 トラブルシューティング

### デプロイが失敗する場合

1. **ログを確認:**
   - Renderダッシュボードの "Logs" タブを確認

2. **よくあるエラー:**

   - `Blocked host` エラー:
     → 環境変数が正しく設定されているか確認
     
   - `Database migration failed`:
     → "Manual Deploy" → "Clear build cache & deploy" を実行
     
   - `Assets precompilation failed`:
     → `RAILS_MASTER_KEY` が正確にコピーされているか確認

### アプリが起動しない場合

1. Environment タブで環境変数を再確認
2. "Manual Deploy" → "Deploy latest commit" で再デプロイ

### スリープから復帰が遅い（無料プラン）

無料プランでは非アクティブ時にスリープします:
- 初回アクセス時: 30秒〜1分程度かかる
- アクティブ時: 通常速度

**常時起動にする場合:** プランを $7/月 にアップグレード

---

## 📊 Render.yaml による自動デプロイ

このプロジェクトには `render.yaml` が含まれています。

### Blueprintからデプロイする場合:

1. Renderダッシュボードで "New +" → "Blueprint"
2. リポジトリを選択
3. `render.yaml` が自動検出される
4. `RAILS_MASTER_KEY` のみ手動で設定
5. "Apply" をクリック

これにより、上記の設定が自動的に適用されます。

---

## 🔄 更新のデプロイ

コードを更新した場合:

```bash
git add .
git commit -m "Update feature"
git push origin TimeLine
```

Renderが自動的に検出して再デプロイします。

---

## 💰 料金プラン

### 無料プラン
- 月750時間まで無料
- 非アクティブ15分後にスリープ
- 512MB RAM
- 十分に試用可能

### 有料プラン（$7/月〜）
- 常時起動
- より高速
- より多くのRAM

---

## 🎯 次のステップ

デプロイ成功後:
1. ✅ 動画をアップロードしてテスト
2. ✅ MediaPipe eye trackingの動作確認
3. ✅ 問題の追加とクイズ機能テスト
4. ✅ アナリティクスダッシュボード確認
5. ✅ CSVエクスポート機能テスト

---

問題があれば、Renderのログを確認するか、サポートに連絡してください！
