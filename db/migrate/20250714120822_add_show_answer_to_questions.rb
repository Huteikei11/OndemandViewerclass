class AddShowAnswerToQuestions < ActiveRecord::Migration[8.0]
  def change
    add_column :questions, :show_answer, :boolean, default: true
  end
end
