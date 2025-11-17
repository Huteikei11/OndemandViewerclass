class Video < ApplicationRecord
  # Associations
  belongs_to :creator, class_name: "User", optional: true
  has_many :questions, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :video_managers, dependent: :destroy
  has_many :managers, through: :video_managers, source: :user
  has_many :video_accesses, dependent: :destroy
  has_many :authorized_users, through: :video_accesses, source: :user
  has_many :user_responses, through: :questions
  has_many :learning_sessions, dependent: :destroy

  has_one_attached :video_file
  has_one_attached :pdf_file

  # Validations
  validates :title, presence: true
  validates :video_file, presence: true
  validates :password, presence: true, if: :is_private?

  # Scopes
  scope :public_videos, -> { where(is_private: [ false, nil ]) }
  scope :private_videos, -> { where(is_private: true) }

  # Methods
  def is_private?
    is_private == true
  end

  def can_be_accessed_by?(user)
    return true unless is_private?
    return false unless user

    creator == user || managers.include?(user) || authorized_users.include?(user)
  end

  def authenticate_with_password(input_password)
    return true unless is_private?
    password == input_password
  end
end
