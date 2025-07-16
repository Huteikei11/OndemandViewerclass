class VideoAccessController < ApplicationController
  before_action :authenticate_user!, except: [:index, :new, :create]

  def index
    if user_signed_in?
      @public_videos = Video.public_videos
      @accessible_videos = current_user.accessible_videos.private_videos
    else
      @public_videos = Video.public_videos
      @accessible_videos = []
    end
  end

  def new
    # 動画IDとパスワード入力フォーム
  end

  def create
    video = Video.find_by(id: params[:video_id])
    
    if video.nil?
      redirect_to video_access_new_path, alert: '動画が見つかりません。'
      return
    end

    if video.authenticate_with_password(params[:password])
      if user_signed_in?
        # ログイン済みユーザーはアクセス権限を追加
        unless current_user.can_access_video?(video)
          current_user.video_accesses.create(video: video)
        end
        redirect_to player_video_path(video), notice: '動画へのアクセスが許可されました。'
      else
        # 未ログインユーザーは一時的にセッションで管理
        session[:temp_video_access] ||= []
        session[:temp_video_access] << video.id unless session[:temp_video_access].include?(video.id)
        redirect_to player_video_path(video), notice: '動画へのアクセスが許可されました。'
      end
    else
      redirect_to video_access_new_path, alert: 'パスワードが正しくありません。'
    end
  end

  private

  def video_access_params
    params.permit(:video_id, :password)
  end
end
