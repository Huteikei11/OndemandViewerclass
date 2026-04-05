module Api
  class VideosController < ApplicationController
    before_action :authenticate_user!
    before_action :set_video, only: [ :new_session ]

    # 新規セッションを開始
    def new_session
      if !@video.can_be_accessed_by?(current_user)
        render json: { error: "アクセス権限がありません" }, status: :unauthorized
        return
      end

      # 既存の進行中セッションを終了
      active_session = current_user.learning_sessions.active_for(current_user.id, @video.id).first
      if active_session
        active_session.deactivate!
      end

      # 新規セッションを作成
      new_session = LearningSession.create!(
        user: current_user,
        video: @video,
        session_start_time: Time.current,
        is_active: true,
        last_video_time: 0.0,
        last_session_elapsed: 0.0
      )

      render json: {
        success: true,
        session_id: new_session.id,
        message: "新しいセッションが開始されました"
      }
    end

    private

    def set_video
      @video = Video.find(params[:id])
    end
  end
end
