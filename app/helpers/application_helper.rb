module ApplicationHelper
  def question_type_display(question_type)
    case question_type
    when "true_false"
      "○×問題"
    when "multiple_choice"
      "選択問題"
    when "free_response"
      "記述問題"
    else
      question_type
    end
  end

  def question_type_badge_class(question_type)
    case question_type
    when "true_false"
      "bg-primary"
    when "multiple_choice"
      "bg-success"
    when "free_response"
      "bg-info"
    else
      "bg-secondary"
    end
  end

  def format_time_position(seconds)
    minutes = seconds / 60
    secs = seconds % 60
    sprintf("%02d:%02d", minutes, secs)
  end

  # タイムライン用のヘルパーメソッド
  def get_event_type_class(event_type)
    case event_type.to_s
    when /session/
      "session"
    when /video/
      "video"
    when /question/, /answer/
      "question"
    when /score/
      "score"
    when /interaction/, /note/
      "interaction"
    else
      "default"
    end
  end

  def get_event_icon(event_type)
    case event_type.to_s
    when /session_start/
      "fas fa-play"
    when /session_end/
      "fas fa-stop"
    when /video_play/
      "fas fa-play-circle"
    when /video_pause/
      "fas fa-pause-circle"
    when /question/
      "fas fa-question-circle"
    when /answer/
      "fas fa-check-circle"
    when /score/
      "fas fa-chart-line"
    when /note/
      "fas fa-sticky-note"
    else
      "fas fa-circle"
    end
  end

  def get_event_badge_color(event_type)
    case event_type.to_s
    when /session/
      "primary"
    when /video/
      "secondary"
    when /question/, /answer/
      "warning"
    when /score/
      "success"
    when /interaction/, /note/
      "info"
    else
      "light"
    end
  end

  def get_event_type_name(event_type)
    case event_type.to_s
    when /session_start/
      "セッション開始"
    when /session_end/
      "セッション終了"
    when /video_play/
      "動画再生"
    when /video_pause/
      "動画停止"
    when /question_display/
      "問題表示"
    when /answer/
      "回答"
    when /score_change/
      "スコア変更"
    when /interaction_note/
      "メモ入力"
    else
      event_type.humanize
    end
  end

  def format_video_time(seconds)
    return "00:00" if seconds.nil? || seconds == 0

    hours = seconds.to_i / 3600
    minutes = (seconds.to_i % 3600) / 60
    secs = seconds.to_i % 60

    if hours > 0
      sprintf("%02d:%02d:%02d", hours, minutes, secs)
    else
      sprintf("%02d:%02d", minutes, secs)
    end
  end

  def format_duration(seconds)
    return "00:00" if seconds.nil? || seconds == 0

    minutes = seconds.to_i / 60
    secs = seconds.to_i % 60
    sprintf("%02d:%02d", minutes, secs)
  end
end
