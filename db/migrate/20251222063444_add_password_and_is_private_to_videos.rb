class AddPasswordAndIsPrivateToVideos < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:videos, :password_digest)
      add_column :videos, :password_digest, :string
    end
    
    unless column_exists?(:videos, :is_private)
      add_column :videos, :is_private, :boolean, default: false
      # 既存のレコードにデフォルト値を設定
      Video.reset_column_information
      Video.update_all(is_private: false)
    end
  end
end
