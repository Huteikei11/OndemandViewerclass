class CreateTimestampEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :timestamp_events do |t|
      t.references :learning_session, null: false, foreign_key: true
      t.datetime :timestamp
      t.float :session_elapsed
      t.float :video_time
      t.string :event_type
      t.text :description
      t.float :concentration_score
      t.string :video_state
      t.float :playback_rate
      t.text :additional_data

      t.timestamps
    end
  end
end
