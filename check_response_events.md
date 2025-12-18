# 反応速度イベント記録の確認方法

## 1. イベント記録の仕組み

### フロントエンド（player.html.erb）

**記録タイミング**: 
- 問題が表示されたとき → `this.questionDisplayTime` に時刻を記録
- 回答が開始されたとき → `this.responseStartTime` に時刻を記録
- `updateConcentrationScore()` メソッド内で回答時間を計算して判定

**判定ロジック** (2345-2370行目):
```javascript
const responseTime = (this.responseStartTime - this.questionDisplayTime) / 1000;

if (responseTime > this.scoreSettings.responseDelayThreshold) {
  // 遅延判定（デフォルト: 20秒以上）
  this.addTimestamp('response_slow', '回答遅延', {
    responseTime: responseTime,
    threshold: this.scoreSettings.responseDelayThreshold,
    delay: responseTime - this.scoreSettings.responseDelayThreshold
  });
} else if (responseTime < this.scoreSettings.quickResponseThreshold) {
  // 素早い判定（デフォルト: 10秒未満）
  this.addTimestamp('response_quick', '素早い回答', {
    responseTime: responseTime,
    threshold: this.scoreSettings.quickResponseThreshold
  });
}
```

**addTimestamp メソッド** (2763-2810行目):
- `timestampLog` 配列にイベントを追加
- 以下の情報を含む:
  - `eventType`: 'response_slow' または 'response_quick'
  - `description`: '回答遅延' または '素早い回答'
  - `sessionElapsed`: セッション開始からの経過時間（秒）
  - `videoTime`: 動画の現在位置（秒）
  - `concentrationScore`: 現在の集中度スコア
  - `additionalData`: responseTime, threshold, delayなどの追加情報

**サーバーへの保存** (2907-2980行目):
- `saveSessionToServer()` メソッドで定期的に保存
- `prepareSessionData()` で `timestampLog` 全体をJSON化
- POST `/videos/{video_id}/management/save_session` にデータ送信

### バックエンド（video_management_controller.rb）

**save_session_data メソッド** (131-213行目):
1. JSONデータを受信してパース
2. `LearningSession` を検索または作成
3. `timestampLog` 配列を1件ずつ処理
4. `TimestampEvent` テーブルに以下のカラムで保存:
   - `event_type`: 'response_slow' または 'response_quick'
   - `description`: '回答遅延' または '素早い回答'
   - `session_elapsed`: 経過時間
   - `video_time`: 動画時間
   - `concentration_score`: 集中度
   - `additional_data`: JSON形式で追加情報（responseTime等）

### 分析画面での表示（analytics.html.erb）

**データ取得** (video_management_controller.rb 419-433行目):
```ruby
@response_time_markers = @learning_sessions.map do |session|
  response_events = session.timestamp_events
                          .where("event_type IN (?)", ["response_quick", "response_slow"])
  quick_events = response_events.select { |e| e.event_type == "response_quick" }
  slow_events = response_events.select { |e| e.event_type == "response_slow" }
  # ...
end
```

**表示方法** (analytics.html.erb 1165-1207行目):
- ピンク色 (#ff69b4) のマーカー
- 素早い回答: 星形（★）
- 回答遅延: クロス（×）
- ツールチップに回答時間を表示

## 2. 確認方法

### A. ブラウザコンソールで確認

動画プレイヤーで問題に回答すると、以下のようなログが表示されます:

```
[反応速度イベント] 回答時間: 8.45秒
[反応速度イベント] 遅延判定閾値: 20秒
[反応速度イベント] 素早い判定閾値: 10秒
[反応速度イベント] 素早い回答を記録: 8.45秒
[タイムスタンプ追加] response_quick: 素早い回答
```

### B. データベースで確認

```bash
cd /home/anada/OndemandViewerclass
sqlite3 storage/development.sqlite3
```

```sql
-- 反応速度イベントの一覧を確認
SELECT 
  te.id,
  te.event_type,
  te.description,
  te.session_elapsed,
  te.video_time,
  te.additional_data,
  ls.id as session_id,
  u.email
FROM timestamp_events te
JOIN learning_sessions ls ON te.learning_session_id = ls.id
JOIN users u ON ls.user_id = u.id
WHERE te.event_type IN ('response_quick', 'response_slow')
ORDER BY te.created_at DESC
LIMIT 20;

-- セッションごとの反応速度イベント数
SELECT 
  ls.id,
  u.email,
  COUNT(CASE WHEN te.event_type = 'response_quick' THEN 1 END) as quick_count,
  COUNT(CASE WHEN te.event_type = 'response_slow' THEN 1 END) as slow_count
FROM learning_sessions ls
JOIN users u ON ls.user_id = u.id
LEFT JOIN timestamp_events te ON te.learning_session_id = ls.id 
  AND te.event_type IN ('response_quick', 'response_slow')
GROUP BY ls.id, u.email
HAVING quick_count > 0 OR slow_count > 0
ORDER BY ls.created_at DESC;
```

### C. 分析画面で確認

1. 動画管理画面にアクセス: `/videos/{video_id}/management/analytics`
2. 「学習タイムライン分析」グラフを確認
3. ピンク色の★（素早い回答）や×（回答遅延）のマーカーが表示されているか確認
4. マーカーにマウスホバーすると回答時間が表示される

### D. Rails ログで確認

```bash
tail -f log/development.log
```

セッション保存時に以下のようなログが出力されます:
```
セッション保存開始 - ユーザー: 1, 動画: 2
XX件の新しいタイムスタンプイベントを保存しました
```

## 3. 記録されない場合のトラブルシューティング

### チェックポイント:

1. **問題表示イベントが発生しているか**
   - `this.questionDisplayTime` が設定されているか確認
   - ブラウザコンソールで `window.concentrationTracker.questionDisplayTime` を確認

2. **回答開始イベントが発生しているか**
   - `this.responseStartTime` が設定されているか確認
   - `onResponseStart()` メソッドが呼ばれているか確認

3. **`responseProcessed` フラグの状態**
   - 一度判定したら `true` になるので、次の問題で `false` にリセットされているか
   - 問題表示時に `this.responseProcessed = false` が実行されているか確認

4. **閾値の設定**
   - デフォルト設定:
     - `responseDelayThreshold`: 20秒
     - `quickResponseThreshold`: 10秒
   - 10秒未満なら「素早い」、20秒以上なら「遅延」、10-20秒は記録なし

5. **データ送信の確認**
   - ブラウザのネットワークタブで `/management/save_session` へのPOSTを確認
   - レスポンスが `{success: true}` になっているか確認

## 4. デバッグコマンド

ブラウザコンソールで実行:

```javascript
// タイムスタンプログ全体を確認
console.table(window.concentrationTracker.timestampLog);

// 反応速度イベントのみフィルタ
window.concentrationTracker.timestampLog.filter(e => 
  e.eventType === 'response_quick' || e.eventType === 'response_slow'
);

// 手動でセッション保存
window.concentrationTracker.saveSessionToServer();

// 現在の設定を確認
console.log(window.concentrationTracker.scoreSettings);
```
