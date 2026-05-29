# 反応時間統計の実装ガイド

## ステップ1: マイグレーション（reaction_time_metrics テーブル作成）

```ruby
# db/migrate/[timestamp]_create_reaction_time_metrics.rb
class CreateReactionTimeMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :reaction_time_metrics do |t|
      t.references :learning_session, foreign_key: true
      t.bigint :question_display_event_id
      t.bigint :gaze_detection_event_id
      t.bigint :answer_event_id
      
      # 時間指標（秒）
      t.float :gaze_reaction_time_sec          # 問題表示 → 視線反応
      t.float :gaze_to_answer_time_sec         # 視線反応 → 回答
      t.float :total_response_time_sec         # 問題表示 → 回答
      
      # 視線速度
      t.float :gaze_velocity_x
      t.float :gaze_velocity_y
      
      # 判定フラグ
      t.boolean :gaze_detected
      t.string :response_category              # 'quick', 'normal', 'slow'
      
      # パフォーマンス指標
      t.boolean :answer_is_correct
      t.float :concentration_at_gaze
      t.float :concentration_at_answer
      
      # ユーザー・問題情報（キャッシュ）
      t.references :user, foreign_key: true
      t.references :question, foreign_key: true
      t.references :video, foreign_key: true
      
      t.timestamps
    end
    
    add_index :reaction_time_metrics, [:learning_session_id, :created_at]
    add_index :reaction_time_metrics, [:user_id, :created_at]
    add_index :reaction_time_metrics, [:video_id, :created_at]
    add_index :reaction_time_metrics, :response_category
  end
end
```

---

## ステップ2: モデル実装

```ruby
# app/models/reaction_time_metric.rb
class ReactionTimeMetric < ApplicationRecord
  belongs_to :learning_session
  belongs_to :user
  belongs_to :question, optional: true
  belongs_to :video
  
  # スコープ
  scope :with_gaze, -> { where(gaze_detected: true) }
  scope :without_gaze, -> { where(gaze_detected: false) }
  scope :quick_responses, -> { where(response_category: 'quick') }
  scope :normal_responses, -> { where(response_category: 'normal') }
  scope :slow_responses, -> { where(response_category: 'slow') }
  scope :correct_answers, -> { where(answer_is_correct: true) }
  scope :recent, ->(days = 7) { where('created_at > ?', days.days.ago) }
  
  # バリデーション
  validates :learning_session_id, :video_id, :user_id, presence: true
  validates :gaze_reaction_time_sec, :total_response_time_sec, 
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # クラスメソッド: データ生成（バッチ処理）
  def self.generate_from_timestamp_events
    puts "Starting reaction_time_metrics generation..."
    
    learning_sessions = LearningSession.includes(:user, :video, :timestamp_events).limit(1000)
    
    learning_sessions.each do |session|
      question_display_events = session.timestamp_events.where(event_type: 'question_display')
      
      question_display_events.each do |q_event|
        # 視線反応イベントを検索
        gaze_events = session.timestamp_events.where(event_type: 'quick_question_check')
          .where('session_elapsed > ?', q_event.session_elapsed)
          .where('session_elapsed <= ?', q_event.session_elapsed + 4)
        
        # 回答イベントを検索
        answer_events = session.timestamp_events.where(event_type: 'answer_start')
          .where('session_elapsed > ?', q_event.session_elapsed)
          .where('session_elapsed < ?', q_event.session_elapsed + 60)
        
        # 視線反応時間を計算
        g_event = gaze_events.first
        gaze_reaction_time = g_event ? (g_event.session_elapsed - q_event.session_elapsed) : nil
        
        # 回答時間を計算
        a_event = answer_events.first
        total_response_time = a_event ? (a_event.session_elapsed - q_event.session_elapsed) : nil
        gaze_to_answer_time = if g_event && a_event
                                (a_event.session_elapsed - g_event.session_elapsed)
                              elsif total_response_time
                                total_response_time
                              else
                                nil
                              end
        
        # レコード作成
        ReactionTimeMetric.create(
          learning_session: session,
          user: session.user,
          video: session.video,
          question_display_event_id: q_event.id,
          gaze_detection_event_id: g_event&.id,
          answer_event_id: a_event&.id,
          
          gaze_reaction_time_sec: gaze_reaction_time,
          gaze_to_answer_time_sec: gaze_to_answer_time,
          total_response_time_sec: total_response_time,
          
          gaze_velocity_x: g_event&.additional_data&.dig('gazeVelocityX')&.to_f,
          gaze_velocity_y: g_event&.additional_data&.dig('gazeVelocityY')&.to_f,
          
          gaze_detected: g_event.present?,
          response_category: categorize_response(total_response_time),
          
          answer_is_correct: a_event.present?, # 要調整: 実際の正答判定ロジック
          concentration_at_gaze: g_event&.concentration_score,
          concentration_at_answer: a_event&.concentration_score
        )
      end
    end
    
    puts "Completed!"
  end
  
  private
  
  def self.categorize_response(response_time_sec)
    return nil if response_time_sec.nil?
    
    case response_time_sec
    when 0...10 then 'quick'
    when 10...30 then 'normal'
    else 'slow'
    end
  end
end
```

---

## ステップ3: 統計分析クエリ

```ruby
# app/models/user.rb に追加
class User < ApplicationRecord
  def reaction_time_statistics(days = 7)
    metrics = ReactionTimeMetric.where(user_id: id).recent(days)
    
    {
      total_questions: metrics.count,
      avg_gaze_reaction_time: metrics.average(:gaze_reaction_time_sec)&.round(2),
      avg_thinking_time: metrics.average(:gaze_to_answer_time_sec)&.round(2),
      avg_total_response_time: metrics.average(:total_response_time_sec)&.round(2),
      
      gaze_detection_rate: (metrics.with_gaze.count.to_f / metrics.count * 100).round(1),
      quick_response_rate: (metrics.quick_responses.count.to_f / metrics.count * 100).round(1),
      correct_answer_rate: (metrics.correct_answers.count.to_f / metrics.count * 100).round(1),
      
      concentration_avg: metrics.average(:concentration_at_answer)&.round(1),
      
      # パターン分析
      with_gaze_accuracy: metrics.with_gaze.correct_answers.count.to_f / metrics.with_gaze.count,
      without_gaze_accuracy: metrics.without_gaze.correct_answers.count.to_f / metrics.without_gaze.count,
      
      # 改善傾向
      trend: calculate_trend(metrics)
    }
  end
  
  private
  
  def calculate_trend(metrics)
    first_half = metrics.order(:created_at).limit(metrics.count / 2)
    second_half = metrics.order(:created_at).offset(metrics.count / 2)
    
    first_avg = first_half.average(:total_response_time_sec).to_f
    second_avg = second_half.average(:total_response_time_sec).to_f
    
    if first_avg > second_avg
      { direction: 'improving', improvement_rate: ((first_avg - second_avg) / first_avg * 100).round(1) }
    else
      { direction: 'stable_or_declining', change_rate: ((second_avg - first_avg) / first_avg * 100).round(1) }
    end
  end
end
```

---

## ステップ4: コントローラーに分析エンドポイントを追加

```ruby
# app/controllers/video_management_controller.rb に追加
def reaction_time_analysis
  @video = Video.find(params[:video_id])
  check_management_permission
  
  # 動画全体の反応時間統計
  metrics = ReactionTimeMetric.where(video_id: @video.id)
  
  @overall_stats = {
    total_questions_analyzed: metrics.count,
    avg_gaze_reaction_time: metrics.average(:gaze_reaction_time_sec)&.round(2),
    avg_total_response_time: metrics.average(:total_response_time_sec)&.round(2),
    gaze_detection_rate: (metrics.with_gaze.count.to_f / metrics.count * 100).round(1)
  }
  
  # ユーザー別統計
  @user_stats = metrics.group_by(&:user_id).map do |user_id, user_metrics|
    user = User.find(user_id)
    {
      user_email: user.email,
      question_count: user_metrics.count,
      avg_gaze_reaction_time: user_metrics.map(&:gaze_reaction_time_sec).compact.sum / user_metrics.count.to_f,
      avg_response_time: user_metrics.map(&:total_response_time_sec).compact.sum / user_metrics.count.to_f,
      accuracy_rate: (user_metrics.select(&:answer_is_correct).count.to_f / user_metrics.count * 100).round(1)
    }
  end.sort_by { |s| s[:avg_response_time] }
  
  # 問題別統計
  @question_stats = metrics.group_by(&:question_id).map do |question_id, q_metrics|
    next nil if question_id.nil?
    
    question = Question.find(question_id)
    {
      question: question,
      avg_gaze_reaction_time: q_metrics.map(&:gaze_reaction_time_sec).compact.average,
      avg_response_time: q_metrics.map(&:total_response_time_sec).compact.average,
      accuracy_rate: (q_metrics.select(&:answer_is_correct).count.to_f / q_metrics.count * 100).round(1),
      difficulty_level: assess_difficulty(q_metrics)
    }
  end.compact
  
  render :reaction_time_analysis
end

private

def assess_difficulty(metrics)
  avg_response_time = metrics.map(&:total_response_time_sec).compact.average
  avg_accuracy = metrics.select(&:answer_is_correct).count.to_f / metrics.count * 100
  
  case [avg_response_time > 15, avg_accuracy < 60]
  when [true, true]   then 'very_difficult'
  when [true, false]  then 'difficult'
  when [false, true]  then 'confusing'
  else                     'appropriate'
  end
end
```

---

## ステップ5: ビュー実装例

```erb
<!-- app/views/video_management/reaction_time_analysis.html.erb -->
<div class="container mt-4">
  <h2>反応時間分析</h2>
  
  <!-- 全体統計 -->
  <div class="row mb-4">
    <div class="col-md-4">
      <div class="card">
        <div class="card-body">
          <h5>平均視線反応時間</h5>
          <p class="h3"><%= @overall_stats[:avg_gaze_reaction_time] %>秒</p>
          <small>問題表示から視線が動くまで</small>
        </div>
      </div>
    </div>
    <div class="col-md-4">
      <div class="card">
        <div class="card-body">
          <h5>平均回答時間</h5>
          <p class="h3"><%= @overall_stats[:avg_total_response_time] %>秒</p>
          <small>問題表示から回答まで</small>
        </div>
      </div>
    </div>
    <div class="col-md-4">
      <div class="card">
        <div class="card-body">
          <h5>視線検知率</h5>
          <p class="h3"><%= @overall_stats[:gaze_detection_rate] %>%</p>
          <small>視線反応が記録された比率</small>
        </div>
      </div>
    </div>
  </div>
  
  <!-- ユーザー別分析 -->
  <h4>ユーザー別統計</h4>
  <table class="table">
    <thead>
      <tr>
        <th>ユーザー</th>
        <th>問題数</th>
        <th>平均視線反応時間</th>
        <th>平均回答時間</th>
        <th>正答率</th>
      </tr>
    </thead>
    <tbody>
      <% @user_stats.each do |stat| %>
        <tr>
          <td><%= stat[:user_email] %></td>
          <td><%= stat[:question_count] %></td>
          <td><%= stat[:avg_gaze_reaction_time].round(2) %>秒</td>
          <td><%= stat[:avg_response_time].round(2) %>秒</td>
          <td><%= stat[:accuracy_rate] %>%</td>
        </tr>
      <% end %>
    </tbody>
  </table>
  
  <!-- 問題別分析 -->
  <h4>問題別統計</h4>
  <table class="table">
    <thead>
      <tr>
        <th>問題</th>
        <th>難易度</th>
        <th>平均視線反応時間</th>
        <th>平均回答時間</th>
        <th>正答率</th>
      </tr>
    </thead>
    <tbody>
      <% @question_stats.each do |stat| %>
        <tr>
          <td><%= truncate(stat[:question].content, length: 50) %></td>
          <td>
            <span class="badge badge-<%= difficulty_badge_class(stat[:difficulty_level]) %>">
              <%= I18n.t("difficulty.#{stat[:difficulty_level]}") %>
            </span>
          </td>
          <td><%= stat[:avg_gaze_reaction_time]&.round(2) %>秒</td>
          <td><%= stat[:avg_response_time]&.round(2) %>秒</td>
          <td><%= stat[:accuracy_rate] %>%</td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

---

## ステップ6: Rake タスク（定期実行）

```ruby
# lib/tasks/reaction_time_metrics.rake
namespace :metrics do
  desc 'Generate reaction_time_metrics from timestamp_events'
  task generate_reaction_time: :environment do
    ReactionTimeMetric.generate_from_timestamp_events
  end
  
  desc 'Regenerate metrics for a specific video'
  task :regenerate_for_video, [:video_id] => :environment do |t, args|
    video_id = args.video_id
    ReactionTimeMetric.where(video_id: video_id).delete_all
    
    learning_sessions = LearningSession.where(video_id: video_id)
    learning_sessions.each do |session|
      ReactionTimeMetric.generate_for_session(session)
    end
    
    puts "Regenerated metrics for video #{video_id}"
  end
end
```

実行方法:
```bash
# 全動画のメトリクスを生成
bundle exec rake metrics:generate_reaction_time

# 特定の動画のメトリクスを再生成
bundle exec rake metrics:regenerate_for_video[1]
```

---

## 次のステップ

1. **マイグレーション実行**: `rails db:migrate`
2. **既存データ処理**: `rails metrics:generate_reaction_time`
3. **管理画面に統計ツール追加**: ルート定義とコントローラー追加
4. **リアルタイム計算**: 新しい回答イベント時にメトリクスを即座に生成

この実装により、出題後の視線検知から回答までの時間を**統計情報として活用**できます。
