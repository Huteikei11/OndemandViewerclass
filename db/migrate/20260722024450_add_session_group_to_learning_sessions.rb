class AddSessionGroupToLearningSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :learning_sessions, :session_group, :string
  end
end
