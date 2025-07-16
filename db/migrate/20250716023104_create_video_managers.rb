class CreateVideoManagers < ActiveRecord::Migration[8.0]
  def change
    create_table :video_managers do |t|
      t.references :video, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
