class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :created_videos, class_name: "Video", foreign_key: "creator_id", dependent: :destroy
  has_many :video_managers, dependent: :destroy
  has_many :managed_videos, through: :video_managers, source: :video
  has_many :video_accesses, dependent: :destroy
  has_many :accessible_videos, through: :video_accesses, source: :video
  has_many :user_responses, dependent: :destroy
  has_many :notes, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { minimum: 1 }

  # Check if user can manage a video
  def can_manage_video?(video)
    video.creator == self || managed_videos.include?(video)
  end

  # Check if user can access a video
  def can_access_video?(video)
    return true unless video.is_private?
    can_manage_video?(video) || accessible_videos.include?(video)
  end
end
