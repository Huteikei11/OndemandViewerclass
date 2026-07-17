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

  # dependent: false で自動purgeを無効化し、before_destroyで共有状態を確認して安全に削除する
  has_one_attached :video_file, dependent: false
  has_one_attached :pdf_file, dependent: false

  # Password authentication for private videos
  has_secure_password validations: false

  # Validations
  validates :title, presence: true
  validates :video_file, presence: true
  validates :password, presence: true, if: :password_required?

  # 限定公開がfalseの場合、パスワードをクリア
  before_save :clear_password_if_not_private

  # 削除前に共有blobを安全に処理（複製動画と同じblobを参照している場合はファイルを残す）
  before_destroy :purge_or_detach_files

  private

  def purge_or_detach_files
    [ :video_file, :pdf_file ].each do |name|
      attached = public_send(name)
      next unless attached.attached?

      blob = attached.blob
      # 他のレコードが同じblobを参照しているか確認
      shared = ActiveStorage::Attachment
        .where(blob_id: blob.id)
        .where.not(record_type: self.class.name, record_id: id)
        .exists?

      if shared
        attached.detach       # attachmentレコードだけ削除、blob・ファイルは残す
      else
        attached.purge_later  # 他に参照がなければblob・ファイルも削除
      end
    end
  end

  def clear_password_if_not_private
    # 限定公開がfalseの場合、パスワードダイジェストをクリア
    if !is_private? && password_digest.present?
      self.password_digest = nil
    end
  end

  def password_required?
    # 限定公開の場合で、かつ既存のパスワードダイジェストがない場合のみパスワードを必須とする
    is_private? && password_digest.blank?
  end

  public

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
    authenticate(input_password)
  end
end
