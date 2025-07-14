class Note < ApplicationRecord
  belongs_to :video

  validates :content, presence: true
end
