class VideoManagementController < ApplicationController
  before_action :authenticate_user!
  before_action :set_video
  before_action :check_management_permission

  def analytics
    @questions = @video.questions.includes(:user_responses, :options).order(:time_position)
    @user_responses = @video.user_responses.includes(:user, :question).order(:created_at)

    # 統計データを計算
    @total_responses = @user_responses.count
    @unique_users = @user_responses.joins(:user).distinct.count(:user_id)
    @correct_responses = @user_responses.where(is_correct: true).count
    @accuracy_rate = @total_responses > 0 ? (@correct_responses.to_f / @total_responses * 100).round(1) : 0

    # 問題別の統計
    @question_stats = @questions.map do |question|
      responses = question.user_responses.includes(:user)
      correct_count = responses.where(is_correct: true).count
      total_count = responses.count
      avg_time = responses.average(:response_time)

      {
        question: question,
        total_responses: total_count,
        correct_responses: correct_count,
        accuracy_rate: total_count > 0 ? (correct_count.to_f / total_count * 100).round(1) : 0,
        average_response_time: avg_time ? (avg_time / 1000.0).round(1) : 0
      }
    end
  end

  def add_manager
    if request.post?
      user = User.find_by(email: params[:user_email])

      if user
        if @video.video_managers.find_by(user: user)
          redirect_to video_management_analytics_path(video_id: @video), alert: "このユーザーは既に管理者です。"
        else
          @video.video_managers.create(user: user)
          redirect_to video_management_analytics_path(video_id: @video), notice: "管理者を追加しました。"
        end
      else
        redirect_to video_management_add_manager_path(video_id: @video), alert: "ユーザーが見つかりません。"
      end
    end
  end

  private

  def set_video
    @video = Video.find(params[:video_id])
  end

  def check_management_permission
    unless current_user.can_manage_video?(@video)
      redirect_to root_path, alert: "この動画を管理する権限がありません。"
    end
  end
end
