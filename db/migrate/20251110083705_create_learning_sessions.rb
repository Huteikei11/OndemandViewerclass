class CreateLearningSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :learning_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :video, null: false, foreign_key: true
      t.datetime :session_start_time
      t.datetime :session_end_time
      t.float :final_score
      t.integer :total_events
      t.text :session_data

      t.timestamps
    end
  end
end
