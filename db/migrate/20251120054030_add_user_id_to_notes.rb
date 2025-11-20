class AddUserIdToNotes < ActiveRecord::Migration[8.0]
  def change
    # まずnullableでカラムを追加
    add_reference :notes, :user, null: true, foreign_key: true
    
    # 既存のnotesに対して、動画の作成者をuser_idとして設定
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE notes
          SET user_id = (SELECT creator_id FROM videos WHERE videos.id = notes.video_id)
          WHERE user_id IS NULL
        SQL
        
        # user_idがまだnullの場合は削除（orphan records）
        execute "DELETE FROM notes WHERE user_id IS NULL"
        
        # null制約を追加
        change_column_null :notes, :user_id, false
      end
    end
  end
end
