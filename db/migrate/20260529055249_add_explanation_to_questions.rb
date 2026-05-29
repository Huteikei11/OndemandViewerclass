class AddExplanationToQuestions < ActiveRecord::Migration[8.0]
  def change
    add_column :questions, :explanation, :text
    add_column :questions, :show_explanation, :boolean, default: false
  end
end
