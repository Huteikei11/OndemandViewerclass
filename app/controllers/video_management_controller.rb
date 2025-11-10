class VideoManagementController < ApplicationController
  before_action :authenticate_user!
  before_action :set_video
  before_action :check_management_permission

  def analytics
    @questions = @video.questions.includes(:user_responses, :options).order(:time_position)
    @user_responses = @video.user_responses.includes(:user, :question).order(:created_at)
    @learning_sessions = @video.learning_sessions.includes(:user, :timestamp_events).order(:session_start_time)

    # 統計データを計算
    @total_responses = @user_responses.count
    @unique_users = @user_responses.joins(:user).distinct.count(:user_id)
    @correct_responses = @user_responses.where(is_correct: true).count
    @accuracy_rate = @total_responses > 0 ? (@correct_responses.to_f / @total_responses * 100).round(1) : 0

    # 学習セッション統計
    @total_sessions = @learning_sessions.count
    @completed_sessions = @learning_sessions.where.not(session_end_time: nil).count
    
    # SQLiteでは時間計算をRubyで行う
    completed_sessions = @learning_sessions.where.not(session_end_time: nil)
    if completed_sessions.any?
      durations = completed_sessions.map do |session|
        (session.session_end_time - session.session_start_time).to_i
      end
      @average_session_duration = durations.sum.to_f / durations.length
    else
      @average_session_duration = nil
    end
    
    @average_final_score = @learning_sessions.where.not(final_score: nil).average(:final_score)

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

  def session_detail
    @session = LearningSession.find(params[:session_id])
    @timestamp_events = @session.timestamp_events.order(:timestamp)
    
    # グラフ用データの準備
    @chart_data = prepare_chart_data(@timestamp_events)
    
    render json: @chart_data if request.xhr?
  end

  def save_session_data
    begin
      Rails.logger.info "セッション保存開始 - ユーザー: #{current_user&.id || '未認証'}, 動画: #{@video.id}"
      
      unless current_user
        Rails.logger.error "セッション保存失敗: ユーザーが認証されていません"
        render json: { success: false, error: 'ユーザー認証が必要です' }, status: 401
        return
      end
      
      # JSONパラメータまたはFormDataパラメータを処理
      session_data_param = params[:session_data]
      Rails.logger.info "受信データ長: #{session_data_param&.length}"
      
      session_data = if session_data_param.is_a?(String)
        JSON.parse(session_data_param)
      else
        JSON.parse(session_data_param)
      end
      
      # 既存セッションを探すか新規作成
      session_info = session_data['sessionInfo']
      timestamp_log = session_data['timestampLog']
      
      learning_session = LearningSession.find_or_create_by(
        user: current_user,
        video: @video,
        session_start_time: Time.at(session_info['startTime'] / 1000)
      ) do |ls|
        ls.session_data = session_info
        ls.total_events = 0
      end
      
      # セッション終了時刻と最終スコアを更新
      if session_info['endTime']
        learning_session.update!(
          session_end_time: Time.at(session_info['endTime'] / 1000),
          final_score: session_data['finalScore'],
          total_events: timestamp_log.length
        )
      end
      
      # 効率的なバッチ処理で重複チェック
      existing_timestamps = learning_session.timestamp_events.pluck(:timestamp).map(&:to_f)
      
      # 新しいイベントのみをフィルタリング
      new_events = timestamp_log.select do |event|
        event_time = Time.at(event['timestamp'] / 1000).to_f
        !existing_timestamps.include?(event_time)
      end
      
      # バッチインサートで一括保存
      if new_events.any?
        events_to_insert = new_events.map do |event|
          {
            learning_session_id: learning_session.id,
            timestamp: Time.at(event['timestamp'] / 1000),
            session_elapsed: event['sessionElapsed'],
            video_time: event['videoTime'],
            event_type: event['eventType'],
            description: event['description'],
            concentration_score: event['concentrationScore'],
            video_state: event['videoState'],
            playback_rate: event['playbackRate'],
            additional_data: event.except('timestamp', 'sessionElapsed', 'videoTime', 'eventType', 'description', 'concentrationScore', 'videoState', 'playbackRate').to_json,
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        
        # 一括挿入
        TimestampEvent.insert_all(events_to_insert)
        Rails.logger.info "#{new_events.length}件の新しいタイムスタンプイベントを保存しました"
      end
      
      render json: { success: true, session_id: learning_session.id }
    rescue => e
      Rails.logger.error "セッションデータ保存エラー: #{e.message}"
      render json: { success: false, error: e.message }, status: 422
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

  def prepare_chart_data(events)
    {
      timeline: events.map { |e| 
        {
          x: e.session_elapsed,
          y: e.concentration_score,
          event: e.event_type,
          description: e.description,
          video_time: e.video_time
        }
      },
      score_changes: events.score_changes.map { |e|
        {
          time: e.session_elapsed,
          score: e.concentration_score,
          change: e.additional_data&.dig('scoreChange') || 0,
          reason: e.description
        }
      },
      video_operations: events.video_operations.map { |e|
        {
          time: e.session_elapsed,
          operation: e.event_type,
          description: e.description,
          video_time: e.video_time
        }
      },
      interactions: events.interactions.map { |e|
        {
          time: e.session_elapsed,
          type: e.event_type,
          description: e.description
        }
      }
    }
  end
end
