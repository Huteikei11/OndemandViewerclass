class AddDurationToVideos < ActiveRecord::Migration[8.0]
  def change
    add_column :videos, :duration, :integer, comment: "動画の長さ（秒）"
  end
end
