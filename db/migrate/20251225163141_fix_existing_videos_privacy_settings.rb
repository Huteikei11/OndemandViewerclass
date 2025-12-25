class FixExistingVideosPrivacySettings < ActiveRecord::Migration[8.0]
  def up
    # 既存のビデオで is_private が NULL の場合は false に設定
    execute "UPDATE videos SET is_private = 0 WHERE is_private IS NULL"
    
    # 既存のビデオで is_private が true だが password_digest が NULL の場合は is_private を false に戻す
    execute "UPDATE videos SET is_private = 0 WHERE is_private = 1 AND (password_digest IS NULL OR password_digest = '')"
  end

  def down
    # ロールバックは不要（データの整合性を保つため）
  end
end
