class AddPasswordAndIsPrivateToVideos < ActiveRecord::Migration[8.0]
  def change
    add_column :videos, :password_digest, :string unless column_exists?(:videos, :password_digest)
    add_column :videos, :is_private, :boolean, default: false unless column_exists?(:videos, :is_private)
  end
end
