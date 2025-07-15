class Question < ApplicationRecord
  belongs_to :video
  has_many :options, dependent: :destroy
  has_many :user_responses, dependent: :destroy

  validates :content, presence: true
  validates :time_position, presence: true
  validates :question_type, presence: true, inclusion: { in: %w[true_false multiple_choice free_response] }

  # 〇×問題のみ回答が必須
  validates :answer, presence: true, if: -> { question_type == "true_false" }

  # 〇×問題の場合、回答は○または×のみ有効
  validates :answer, inclusion: { in: %w[○ ×] }, if: -> { question_type == "true_false" }
end
