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
    return "00:00" unless seconds

    minutes = seconds / 60
    remaining_seconds = seconds % 60
    sprintf("%02d:%02d", minutes, remaining_seconds)
  end
end
