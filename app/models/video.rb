class Video < ApplicationRecord
  has_many :questions, dependent: :destroy
  has_many :notes, dependent: :destroy
  
  has_one_attached :video_file
  has_one_attached :pdf_file

  validates :title, presence: true
  validates :video_file, presence: true
end
