class AddResponseTimeToUserResponses < ActiveRecord::Migration[8.0]
  def change
    add_column :user_responses, :response_time, :integer
  end
end
