class UserResponse < ApplicationRecord
  belongs_to :question

  # user_answerはmultiple_choice以外で必須
  validates :user_answer, presence: true, unless: -> { question&.question_type == 'multiple_choice' }
end
