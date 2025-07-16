class AddUserToUserResponses < ActiveRecord::Migration[8.0]
  def change
    add_reference :user_responses, :user, null: true, foreign_key: true
  end
end
