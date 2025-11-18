class VideoAccessController < ApplicationController
  before_action :authenticate_user!

  def index
    @public_videos = Video.public_videos
    @accessible_videos = current_user.accessible_videos.private_videos
    @my_videos = current_user.created_videos
  end

  def new
    # 動画IDとパスワード入力フォーム
  end

  def create
    video = Video.find_by(id: params[:video_id])

    if video.nil?
      redirect_to video_access_new_path, alert: "動画が見つかりません。"
      return
    end

    if video.authenticate_with_password(params[:password])
      # ログイン済みユーザーはアクセス権限を追加
      unless current_user.can_access_video?(video)
        current_user.video_accesses.create(video: video)
      end
      redirect_to player_video_path(video), notice: "動画へのアクセスが許可されました。"
    else
      redirect_to video_access_new_path, alert: "パスワードが正しくありません。"
    end
  end

  private

  def video_access_params
    params.permit(:video_id, :password)
  end
end
