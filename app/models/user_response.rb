class UserResponse < ApplicationRecord
  belongs_to :question
  belongs_to :user

  # Validations
  validates :user_answer, presence: true, unless: -> { question&.question_type == "multiple_choice" }
  validates :response_time, presence: true, numericality: { greater_than: 0 }

  # Methods
  def is_correct?
    case question.question_type
    when 'true_false', 'free_response'
      user_answer == question.answer
    when 'multiple_choice'
      # For multiple choice, check if the selected option is correct
      selected_option = question.options.find_by(id: selected_option_id)
      selected_option&.is_correct == true
    else
      false
    end
  end

  def response_time_in_seconds
    response_time / 1000.0 # Convert milliseconds to seconds
  end
end
