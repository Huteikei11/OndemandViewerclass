class CreateUserResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :user_responses do |t|
      t.text :user_answer
      t.boolean :is_correct
      t.references :question, null: false, foreign_key: true

      t.timestamps
    end
  end
end
