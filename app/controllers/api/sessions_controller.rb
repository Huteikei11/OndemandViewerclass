module Api
  class SessionsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_session, only: [ :activate, :deactivate ]

    skip_before_action :verify_authenticity_token, only: [ :deactivate ]  # navigator.sendBeacon用

    # セッションをアクティブ化（通常再開）
    def activate
      if @session.user != current_user
        render json: { error: "権限がありません" }, status: :unauthorized
        return
      end

      @session.activate!

      render json: {
        success: true,
        session_id: @session.id,
        message: "セッションがアクティブ化されました"
      }
    end

    # セッションを非アクティブ化（一時停止）
    def deactivate
      if @session.user != current_user
        render json: { error: "権限がありません" }, status: :unauthorized
        return
      end

      # JSONペイロード、またはparams から動画時刻と経過時間を取得
      video_time = (params[:video_time] || request.raw_post).to_f
      session_elapsed = (params[:session_elapsed] || 0).to_f

      # JSONペイロードの場合、parse
      if request.content_type&.include?("application/json") && request.raw_post.present?
        begin
          json_data = JSON.parse(request.raw_post)
          video_time = json_data[:video_time]&.to_f || video_time
          session_elapsed = json_data[:session_elapsed]&.to_f || session_elapsed
        rescue JSON::ParserError
          # JSONパースエラーの場合はスキップ
        end
      end

      @session.deactivate!(video_time, session_elapsed)

      render json: {
        success: true,
        session_id: @session.id,
        message: "セッションが保存されました"
      }
    end

    private

    def set_session
      @session = LearningSession.find(params[:id])
    end
  end
end
