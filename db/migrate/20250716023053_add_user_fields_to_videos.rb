class AddUserFieldsToVideos < ActiveRecord::Migration[8.0]
  def change
    add_reference :videos, :creator, null: true, foreign_key: { to_table: :users }
    add_column :videos, :password, :string
    add_column :videos, :is_private, :boolean, default: false
  end
end
