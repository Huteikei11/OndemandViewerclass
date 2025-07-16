class VideosController < ApplicationController
  before_action :authenticate_user!, except: [:player]
  before_action :set_video, only: [:show, :player, :edit, :update, :destroy]
  before_action :check_video_access, only: [:player]
  before_action :check_video_management, only: [:edit, :update, :destroy]

  def index
    redirect_to video_access_index_path
  end

  def show
    @questions = @video.questions.order(:time_position)
  end

  # Player view for watching videos with questions
  def player
    @questions = @video.questions.order(:time_position)
    @notes = @video.notes.order(:time_position)
    @user_responses = current_user&.user_responses&.joins(:question)&.where(questions: { video_id: @video.id }) || []
  end

  def new
    @video = Video.new
  end

  def create
    @video = Video.new(video_params)
    @video.creator = current_user

    if @video.save
      redirect_to edit_video_path(@video), notice: "動画が正常に作成されました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @questions = @video.questions.order(:time_position)
  end

  def update
    if @video.update(video_params)
      redirect_to edit_video_path(@video), notice: "動画が正常に更新されました。"
    else
      @questions = @video.questions.order(:time_position)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @video.destroy
    redirect_to video_access_index_path, notice: "動画が正常に削除されました。"
  end

  private

  def set_video
    @video = Video.find(params[:id])
  end

  def check_video_access
    return if @video.can_be_accessed_by?(current_user)
    
    # 未ログインユーザーの場合、セッションでの一時アクセスをチェック
    if !user_signed_in? && session[:temp_video_access]&.include?(@video.id)
      return
    end
    
    redirect_to video_access_new_path, alert: 'この動画にアクセスする権限がありません。'
  end

  def check_video_management
    unless current_user.can_manage_video?(@video)
      redirect_to video_access_index_path, alert: 'この動画を管理する権限がありません。'
    end
  end

  def video_params
    params.require(:video).permit(:title, :description, :video_file, :pdf_file, :password, :is_private)
  end
end
