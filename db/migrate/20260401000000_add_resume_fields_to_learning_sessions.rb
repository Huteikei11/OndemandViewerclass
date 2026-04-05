class AddResumeFieldsToLearningSessions < ActiveRecord::Migration[7.0]
  def change
    add_column :learning_sessions, :is_active, :boolean, default: false, null: false
    add_column :learning_sessions, :last_video_time, :float, default: 0.0, null: false
    add_column :learning_sessions, :last_session_elapsed, :float, default: 0.0, null: false
    add_column :learning_sessions, :paused_at, :datetime

    # インデックス追加：ユーザーが特定の動画で進行中のセッションを高速に検索
    add_index :learning_sessions, [ :user_id, :video_id, :is_active ]
    add_index :learning_sessions, [ :user_id, :is_active ]
  end
end
