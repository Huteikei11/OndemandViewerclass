class LearningSession < ApplicationRecord
  belongs_to :user
  belongs_to :video
  has_many :timestamp_events, dependent: :destroy

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }

  # ユーザーが特定の動画で進行中のセッションを取得
  scope :active_for, ->(user_id, video_id) do
    where(user_id: user_id, video_id: video_id, is_active: true)
  end

  # ユーザーが特定の動画で最後に視聴したセッション（進行中でなくても）を取得
  scope :last_session_for, ->(user_id, video_id) do
    where(user_id: user_id, video_id: video_id)
      .order(session_start_time: :desc)
      .limit(1)
  end

  # セッションに関連する回答を取得するための関連付け
  # user_responsesはlearning_session_idを持たないため、明示的にスコープで定義
  def associated_user_responses
    return UserResponse.none unless user_id && video_id && session_start_time

    # このセッションの時間範囲内に、このユーザーが、この動画の問題に対して行った回答
    end_time = session_end_time || Time.current
    UserResponse.joins(:question)
                .where(user_id: user_id)
                .where(questions: { video_id: video_id })
                .where("user_responses.created_at >= ? AND user_responses.created_at <= ?",
                       session_start_time, end_time)
  end

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

  # ====== 再開機能関連メソッド ======

  # last_video_time の値を取得（カラム未存在時は session_data をフォールバックに使用）
  def last_video_time_value
    if has_attribute?(:last_video_time)
      last_video_time.to_f
    else
      sd = session_data.is_a?(Hash) ? session_data : {}
      sd["last_video_time"].to_f
    end
  rescue
    0.0
  end

  # last_session_elapsed の値を取得（カラム未存在時は session_data をフォールバックに使用）
  def last_session_elapsed_value
    if has_attribute?(:last_session_elapsed)
      last_session_elapsed.to_f
    else
      sd = session_data.is_a?(Hash) ? session_data : {}
      sd["last_session_elapsed"].to_f
    end
  rescue
    0.0
  end

  # セッションをアクティブ化（再生開始）
  def activate!
    attrs = { paused_at: nil }
    attrs[:is_active] = true if has_attribute?(:is_active)
    update(attrs)
  end

  # セッションを非アクティブ化（一時停止）
  def deactivate!(video_time = nil, session_elapsed = nil)
    attrs = { paused_at: Time.current }
    attrs[:is_active] = false if has_attribute?(:is_active)
    if has_attribute?(:last_video_time)
      attrs[:last_video_time] = (video_time && video_time > 0) ? video_time : last_video_time
      attrs[:last_session_elapsed] = (session_elapsed && session_elapsed > 0) ? session_elapsed : last_session_elapsed
    elsif video_time && video_time > 0
      sd = (session_data.is_a?(Hash) ? session_data : {}).merge(
        "last_video_time" => video_time,
        "last_session_elapsed" => session_elapsed.to_f
      )
      attrs[:session_data] = sd
    end
    update(attrs)
  end

  # セッションが再開可能か判定（再生位置があるか）
  def can_resume?
    last_video_time_value > 0
  end

  # 再開時刻をフォーマット（MM:SS形式）
  def formatted_resume_time
    video_time = last_video_time_value
    return "00:00" if video_time <= 0
    minutes = (video_time / 60).floor
    seconds = (video_time % 60).floor
    "#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
  rescue
    "00:00"
  end

  # セッション開始からの経過時間をフォーマット（秒）
  def formatted_resume_session_elapsed
    last_session_elapsed_value.floor
  end

  # 再開情報を取得
  def resume_info
    {
      video_time: last_video_time_value,
      session_elapsed: last_session_elapsed_value,
      formatted_time: formatted_resume_time,
      paused_at: has_attribute?(:paused_at) ? paused_at : nil,
      is_active: has_attribute?(:is_active) ? is_active : false
    }
  end
end
