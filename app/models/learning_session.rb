class LearningSession < ApplicationRecord
  belongs_to :user
  belongs_to :video
  has_many :timestamp_events, dependent: :destroy

  # セッションデータをJSONとして扱う
  serialize :session_data, coder: JSON

  validates :session_start_time, presence: true

  def duration
    return 0 unless session_end_time && session_start_time
    (session_end_time - session_start_time).to_i
  end

  def duration_in_minutes
    return 0.0 unless session_end_time && session_start_time
    duration / 60.0
  end

  def format_duration
    return "進行中" unless session_end_time

    duration_seconds = duration
    hours = duration_seconds / 3600
    minutes = (duration_seconds % 3600) / 60
    seconds = duration_seconds % 60

    if hours > 0
      "#{hours}時間#{minutes}分#{seconds}秒"
    elsif minutes > 0
      "#{minutes}分#{seconds}秒"
    else
      "#{seconds}秒"
    end
  end

  def score_events
    timestamp_events.where("event_type LIKE '%score%'")
  end

  def video_events
    timestamp_events.where("event_type LIKE '%video%'")
  end

  def interaction_events
    timestamp_events.where("event_type LIKE '%interaction%'")
  end

  # 動画操作統計
  def video_operation_stats
    {
      pause_count: timestamp_events.where("event_type LIKE '%pause%'").count,
      forward_seek_count: timestamp_events.where("event_type LIKE '%seek%' AND description LIKE '%前進%' OR description LIKE '%進む%' OR description LIKE '%早送り%'").count,
      backward_seek_count: timestamp_events.where("event_type LIKE '%seek%' AND description LIKE '%後退%' OR description LIKE '%戻る%' OR description LIKE '%巻き戻し%'").count,
      playback_rate_change_count: timestamp_events.where("event_type LIKE '%playback%' OR event_type LIKE '%speed%' OR description LIKE '%再生速度%'").count
    }
  end

  # 平均集中度スコアを計算
  def average_concentration_score
    concentration_events = timestamp_events.where("event_type LIKE '%concentration%'")
    return nil if concentration_events.empty?

    scores = concentration_events.map do |event|
      if event.description && event.description.match(/(\d+\.?\d*)/)
        $1.to_f
      else
        nil
      end
    end.compact

    return nil if scores.empty?
    scores.sum / scores.length
  end
end
