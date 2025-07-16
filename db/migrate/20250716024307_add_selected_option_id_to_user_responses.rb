class AddSelectedOptionIdToUserResponses < ActiveRecord::Migration[8.0]
  def change
    add_column :user_responses, :selected_option_id, :integer
  end
end
