module VideosHelper
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
      "badge-primary"
    when "multiple_choice"
      "badge-success"
    when "free_response"
      "badge-info"
    else
      "badge-secondary"
    end
  end

  def format_time_position(seconds)
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60
    if hours > 0
      sprintf("%d:%02d:%02d", hours, minutes, secs)
    else
      sprintf("%02d:%02d", minutes, secs)
    end
  end
end
