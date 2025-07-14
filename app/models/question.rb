class Question < ApplicationRecord
  belongs_to :video
  has_many :options, dependent: :destroy
  has_many :user_responses, dependent: :destroy

  validates :content, presence: true
  validates :time_position, presence: true
  validates :question_type, presence: true, inclusion: { in: %w[true_false multiple_choice free_response] }
  
  # Only validate answer for true_false and free_response questions
  validates :answer, presence: true, if: -> { %w[true_false free_response].include?(question_type) }
end
