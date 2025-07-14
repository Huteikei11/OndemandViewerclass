class UserResponse < ApplicationRecord
  belongs_to :question

  validates :user_answer, presence: true
end
