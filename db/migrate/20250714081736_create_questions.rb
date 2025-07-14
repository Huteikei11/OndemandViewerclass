class CreateQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :questions do |t|
      t.text :content
      t.text :answer
      t.string :question_type
      t.integer :time_position
      t.references :video, null: false, foreign_key: true

      t.timestamps
    end
  end
end
