# 出題後の視線検知と反応時間統計の活用可能性

## 1. 現在の実装状況

### ✅ 記録されているイベント

#### 1.1 問題表示イベント
```
event_type: 'question_display'
記録内容: 問題が画面に表示された時刻
時刻基準: this.questionDisplayTime = Date.now()
```

#### 1.2 視線反応イベント（出題後の視線検知）
```
event_type: 'quick_question_check'
発生条件: 問題表示後4秒以内に視線速度が10px/s以上に達した
記録内容:
  - timeFromQuestion: 問題表示から視線検知までの時間（秒）
  - gazeVelocityX: X軸の視線速度（px/s）
  - gazeVelocityY: Y軸の視線速度（px/s）
  - threshold: 判定に使用した閾値（px/s）

データベース統計:
  - quick_question_check イベント: 10件
```

#### 1.3 回答開始イベント
```
event_type: 'answer_start'
記録内容: ユーザーが回答を開始した時刻
時刻基準: this.responseStartTime = Date.now()
```

#### 1.4 回答速度分類イベント
```
event_type: 'response_quick'    (回答 < 10秒)
event_type: 'response_normal'   (10秒 ≤ 回答 ≤ 20秒)
event_type: 'response_slow'     (回答 > 20秒)

現在の実装:
  - response_quick: 10件
  - response_normal: 5件
  - response_slow: 2件
```

---

## 2. 計算可能な統計情報

### 段階1: 基本的な反応時間指標

#### 2.1 問題表示から視線反応までの時間（視線反応時間）
```sql
SELECT 
  AVG(s.session_elapsed - q.session_elapsed) as avg_gaze_reaction_time,
  MIN(s.session_elapsed - q.session_elapsed) as min_gaze_reaction_time,
  MAX(s.session_elapsed - q.session_elapsed) as max_gaze_reaction_time,
  STDDEV(s.session_elapsed - q.session_elapsed) as stddev_gaze_reaction_time
FROM timestamp_events q
JOIN timestamp_events s ON 
  q.learning_session_id = s.learning_session_id 
  AND s.session_elapsed BETWEEN q.session_elapsed AND q.session_elapsed + 4
  AND s.description LIKE '%正面注視%'
WHERE q.event_type = 'question_display'
```

**現在のデータから計算結果**:
- 視線反応時間: 0.875秒～3.885秒
- 平均: 約2秒
- ユースケース: **集中力・注意力の測定** - 視線反応が速い = 問題に素早く注視できている

#### 2.2 視線反応から回答までの時間（思考・入力時間）
```
視線反応時間 = 回答時刻 - 視線反応時刻
例: 46.15秒 - 44.015秒 = 2.135秒
```

**ユースケース**: **思考速度や回答入力速度の測定**

#### 2.3 問題表示から回答までの総時間（全体反応時間）
```
全体反応時間 = 回答時刻 - 問題表示時刻
現在のフロント実装: responseTime = (this.responseStartTime - this.questionDisplayTime) / 1000
```

**ユースケース**: **総合的な問題解決速度**

---

### 段階2: 複合的な学習パターン分析

#### 2.4 視線検知の有無による回答時間比較
```
WITH gaze_detected AS (
  SELECT q.learning_session_id, q.id as q_id, 
         COUNT(*) as gaze_count,
         AVG(s.session_elapsed - q.session_elapsed) as avg_gaze_time
  FROM timestamp_events q
  LEFT JOIN timestamp_events s ON q.learning_session_id = s.learning_session_id 
    AND s.description LIKE '%正面注視%'
  WHERE q.event_type = 'question_display'
  GROUP BY q.learning_session_id, q.id
)
SELECT 
  CASE WHEN gaze_count > 0 THEN '視線検知あり' ELSE '視線検知なし' END as gaze_status,
  COUNT(*) as question_count,
  AVG(response_time) as avg_response_time,
  AVG(correct) as accuracy_rate
FROM gaze_detected g
JOIN user_responses ur ON g.learning_session_id = ur.user_id  -- 要調整
GROUP BY gaze_status
```

**ユースケース**: 
- **集中度と正答率の相関分析** - 視線検知がある問題の正答率
- **集中時の処理速度** - 視線が向いている時の回答速度

#### 2.5 体験の流れパターン（時系列分析）
```
パターン1: 問題表示 → 視線反応(0.8s) → 回答(2.1s)
          = 高集中度・快速応答

パターン2: 問題表示 → 視線反応(3.8s) → 回答(1.1s)  
          = 初期注視遅延・その後は素早い思考

パターン3: 問題表示 → 視線反応なし → 回答遅延(>20s)
          = 低集中度・思考時間長い
```

---

## 3. 統計情報としての活用シーン

### シーン1: ユーザー学習パフォーマンス分析

#### 3.1 個人別の反応パターンプロファイル
```
ユーザーA: 視線反応時間 平均1.2秒 → 素早く集中できるタイプ
ユーザーB: 視線反応時間 平均3.5秒 → 問題理解に時間がかかるタイプ

→ 推奨学習パターン、サポート内容の個別化が可能
```

#### 3.2 習熟度追跡
```
初期段階: 視線反応時間 4秒、回答時間 15秒
中期段階: 視線反応時間 2秒、回答時間 5秒
熟達段階: 視線反応時間 0.5秒、回答時間 2秒

→ スキル習得の進捗可視化
```

### シーン2: 問題品質評価

#### 3.3 問題の難易度・理解度分析
```
難しい問題:
  - 平均視線反応時間: 長い（理解に時間がかかる）
  - 平均回答時間: 長い
  - 正答率: 低い

わかりやすい問題:
  - 平均視線反応時間: 短い（すぐに理解できる）
  - 平均回答時間: 短い
  - 正答率: 高い

→ 問題の再設計・難易度調整の根拠
```

#### 3.4 問題別の認知負荷分析
```
SELECT question_id, 
       AVG(gaze_reaction_time) as avg_gaze_time,
       AVG(response_time) as avg_response_time,
       AVG(concentration_score) as avg_concentration,
       COUNT(CASE WHEN is_correct THEN 1 END) / COUNT(*) as accuracy
FROM question_performance_metrics
GROUP BY question_id
ORDER BY avg_gaze_time DESC
```

### シーン3: 集中度とパフォーマンスの相関分析

#### 3.5 リアルタイム集中度指標（新規実装可能）
```
集中度スコア = f(視線反応時間, 視線速度, 回答時間, 正答率)

例：
集中度スコア = (
  (1 / gaze_reaction_time) * 0.3 +        // 素早い視線反応
  (1 / response_time) * 0.3 +              // 素早い回答
  (accuracy_rate) * 0.2 +                  // 正答率
  (concentration_score / 100) * 0.2        // 既存の集中度スコア
)
```

---

## 4. データベース実装例

### 新規テーブル提案: `reaction_time_metrics`

```sql
CREATE TABLE reaction_time_metrics (
  id INTEGER PRIMARY KEY,
  learning_session_id INTEGER,
  question_display_event_id INTEGER,
  gaze_detection_event_id INTEGER,
  answer_event_id INTEGER,
  
  gaze_reaction_time_sec FLOAT,        -- 問題表示から視線反応まで
  gaze_to_answer_time_sec FLOAT,       -- 視線反応から回答まで
  total_response_time_sec FLOAT,       -- 問題表示から回答まで
  
  gaze_velocity_x FLOAT,               -- X軸視線速度（px/s）
  gaze_velocity_y FLOAT,               -- Y軸視線速度（px/s）
  
  gaze_detected BOOLEAN,               -- 視線反応があったか
  response_category VARCHAR,           -- 'quick' / 'normal' / 'slow'
  
  answer_is_correct BOOLEAN,           -- 回答が正解か
  concentration_at_gaze FLOAT,         -- 視線反応時の集中度
  concentration_at_answer FLOAT,       -- 回答時の集中度
  
  created_at TIMESTAMP
);
```

### 集計クエリ例

```sql
-- ユーザーの平均反応パターン
SELECT 
  u.email,
  COUNT(*) as question_count,
  AVG(m.gaze_reaction_time_sec) as avg_gaze_reaction_time,
  AVG(m.gaze_to_answer_time_sec) as avg_thinking_time,
  AVG(m.total_response_time_sec) as avg_total_response_time,
  AVG(m.concentration_at_gaze) as avg_concentration_at_gaze,
  SUM(CASE WHEN m.answer_is_correct THEN 1 ELSE 0 END) / COUNT(*) as accuracy_rate
FROM reaction_time_metrics m
JOIN learning_sessions ls ON m.learning_session_id = ls.id
JOIN users u ON ls.user_id = u.id
GROUP BY u.id
ORDER BY avg_gaze_reaction_time ASC;
```

---

## 5. 実装ロードマップ

### Phase 1: データ抽出（すぐに実装可能）
- [x] 既存イベントから反応時間を計算
- [ ] `reaction_time_metrics` テーブルの作成
- [ ] 既存の `timestamp_events` データを再計算してデータを格納

### Phase 2: 分析ツール（2-3週間）
- [ ] 管理画面に「反応時間分析」タブを追加
- [ ] ユーザー別の反応パターングラフ
- [ ] 問題別の難易度分析レポート

### Phase 3: リアルタイム集中度スコア（3-4週間）
- [ ] `gaze_reaction_time` を集中度計算に組み込む
- [ ] フロントエンドで反応時間ベースの加減点を実装

### Phase 4: AI分析（今後）
- [ ] 機械学習で個人の学習パターン予測
- [ ] 最適問題順序の提示

---

## 6. 技術的な注意点

### ⚠️ 限界とトレードオフ

1. **データの完全性**
   - MediaPipeが顔検出できない場合、視線検知ができない
   - ネットワーク遅延でイベント記録がズレる可能性

2. **プライバシー**
   - 視線追跡データは比較的デリケートな個人情報
   - GDPR等の規制への対応が必要

3. **パフォーマンス**
   - リアルタイム計算は重い処理
   - バッチ処理で非同期計算することを推奨

---

## 7. 結論

**活用可能性: ✅ 高い**

- ✅ 視線反応時間は確実に記録されている
- ✅ 複数の統計指標を計算できる
- ✅ ユーザーの学習パターン分析に有用
- ✅ 問題品質評価の根拠となる
- ✅ 個別化された学習支援が可能

**推奨される優先実装**:
1. 反応時間の集計クエリ実装 （1日）
2. 管理画面への分析ツール追加 （1週間）
3. ユーザーの反応パターン可視化 （1週間）
