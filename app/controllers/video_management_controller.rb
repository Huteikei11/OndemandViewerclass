class VideoManagementController < ApplicationController
  before_action :authenticate_user!
  before_action :set_video
  before_action :check_management_permission, except: [ :save_session_data ]

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

    # 動画操作統計（1分以上のセッションのみ）
    valid_sessions = @learning_sessions.where.not(session_end_time: nil).select do |session|
      session.duration >= 60 # 60秒以上
    end

    if valid_sessions.any?
      total_pause = 0
      total_forward_seek = 0
      total_backward_seek = 0
      total_playback_rate_change = 0

      valid_sessions.each do |session|
        stats = session.video_operation_stats
        total_pause += stats[:pause_count]
        total_forward_seek += stats[:forward_seek_count]
        total_backward_seek += stats[:backward_seek_count]
        total_playback_rate_change += stats[:playback_rate_change_count]
      end

      count = valid_sessions.count.to_f
      @avg_pause_count = (total_pause / count).round(1)
      @avg_forward_seek_count = (total_forward_seek / count).round(1)
      @avg_backward_seek_count = (total_backward_seek / count).round(1)
      @avg_playback_rate_change_count = (total_playback_rate_change / count).round(1)
    else
      @avg_pause_count = 0
      @avg_forward_seek_count = 0
      @avg_backward_seek_count = 0
      @avg_playback_rate_change_count = 0
    end

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

    # グラフ用データを準備
    prepare_analytics_chart_data
  end

  def session_detail
    @session = LearningSession.find(params[:session_id])
    @timestamp_events = @session.timestamp_events.order(:session_elapsed)

    # グラフ用データの準備
    @chart_data = prepare_chart_data(@timestamp_events)

    Rails.logger.info "Session #{params[:session_id]} chart data: #{@chart_data.inspect}"

    render json: @chart_data
  end

  def timeline
    # 分析画面と同じ基本データを取得
    @questions = @video.questions.includes(:user_responses, :options).order(:time_position)
    @user_responses = @video.user_responses.includes(:user, :question).order(:created_at)
    @learning_sessions = @video.learning_sessions.includes(:user, :timestamp_events).order(:session_start_time)

    # タイムライン表示用のデータを準備
    @sessions_with_events = @learning_sessions.includes(:timestamp_events, :user)
                                              .where.not(session_start_time: nil)
                                              .order(:session_start_time)

    # 全セッションの統合タイムライン
    @timeline_events = []

    @sessions_with_events.each do |session|
      session.timestamp_events.order(:timestamp).each do |event|
        @timeline_events << {
          session: session,
          event: event,
          user: session.user,
          formatted_time: event.timestamp.strftime("%Y/%m/%d %H:%M:%S"),
          session_elapsed: event.session_elapsed,
          video_time: event.video_time
        }
      end
    end

    # 時系列順にソート
    @timeline_events.sort_by! { |item| item[:event].timestamp }

    # ページング処理（最新100件）
    @timeline_events = @timeline_events.last(100) if @timeline_events.length > 100
  end

  def save_session_data
    begin
      Rails.logger.info "セッション保存開始 - ユーザー: #{current_user&.id || '未認証'}, 動画: #{@video.id}"

      unless current_user
        Rails.logger.error "セッション保存失敗: ユーザーが認証されていません"
        render json: { success: false, error: "ユーザー認証が必要です" }, status: 401
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
      session_info = session_data["sessionInfo"]
      timestamp_log = session_data["timestampLog"]

      learning_session = LearningSession.find_or_create_by(
        user: current_user,
        video: @video,
        session_start_time: Time.at(session_info["startTime"] / 1000)
      ) do |ls|
        ls.session_data = session_info
        ls.total_events = 0
      end

      # セッション終了時刻と最終スコアを更新
      if session_info["endTime"]
        learning_session.update!(
          session_end_time: Time.at(session_info["endTime"] / 1000),
          final_score: session_data["finalScore"],
          total_events: timestamp_log.length
        )
      end

      # 効率的なバッチ処理で重複チェック
      existing_timestamps = learning_session.timestamp_events.pluck(:timestamp).map(&:to_f)

      # 新しいイベントのみをフィルタリング
      new_events = timestamp_log.select do |event|
        event_time = Time.at(event["timestamp"] / 1000).to_f
        !existing_timestamps.include?(event_time)
      end

      # バッチインサートで一括保存
      if new_events.any?
        events_to_insert = new_events.map do |event|
          {
            learning_session_id: learning_session.id,
            timestamp: Time.at(event["timestamp"] / 1000),
            session_elapsed: event["sessionElapsed"],
            video_time: event["videoTime"],
            event_type: event["eventType"],
            description: event["description"],
            concentration_score: event["concentrationScore"],
            video_state: event["videoState"],
            playback_rate: event["playbackRate"],
            additional_data: event.except("timestamp", "sessionElapsed", "videoTime", "eventType", "description", "concentrationScore", "videoState", "playbackRate").to_json,
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

  def export_session_detail
    require "csv"

    learning_session = @video.learning_sessions.find(params[:session_id])
    events = learning_session.timestamp_events
    ops = learning_session.video_operation_stats

    initial_score = 20
    final_score = learning_session.final_score || 0
    score_change = final_score - initial_score

    # イベント集計
    face_not_detected = events.where("event_type LIKE '%face_not_detected%' OR description LIKE '%顔未検出%'").count
    movement_stop = events.where("event_type LIKE '%movement_stop%' OR description LIKE '%目線停止%'").count
    center_gaze = events.where("event_type LIKE '%center_gaze%' OR description LIKE '%集中注視%'").count
    question_confirm = events.where("event_type LIKE '%question_confirm%' OR description LIKE '%問題確認%'").count
    quick_response = events.where("event_type LIKE '%quick_response%' OR description LIKE '%素早い回答%'").count
    response_delay = events.where("event_type LIKE '%response_delay%' OR description LIKE '%回答遅延%'").count
    note_input = events.where("event_type LIKE '%note%' OR description LIKE '%メモ%'").count
    question_display = events.where("event_type LIKE '%question_display%' OR description LIKE '%問題表示%'").count

    # 問題回答統計
    question_ids = @video.questions.pluck(:id)
    user_responses = UserResponse.where(user: learning_session.user, question_id: question_ids)
    correct_count = user_responses.where(is_correct: true).count
    incorrect_count = user_responses.where(is_correct: false).count

    csv_data = "\uFEFF" + CSV.generate(headers: true, encoding: "UTF-8") do |csv|
      csv << [ "セッション詳細情報" ]
      csv << []
      csv << [ "項目", "値" ]
      csv << [ "セッションID", learning_session.id ]
      csv << [ "ユーザー名", learning_session.user.email ]
      csv << [ "ユーザーID", learning_session.user.id ]
      csv << [ "開始日時", learning_session.session_start_time.strftime("%Y-%m-%d %H:%M:%S") ]
      csv << [ "終了日時", learning_session.session_end_time&.strftime("%Y-%m-%d %H:%M:%S") || "進行中" ]
      csv << [ "セッション時間(秒)", learning_session.duration ]
      csv << [ "セッション時間(分)", learning_session.duration_in_minutes.round(1) ]
      csv << []
      csv << [ "スコア情報" ]
      csv << [ "初期スコア", initial_score ]
      csv << [ "最終スコア", final_score ]
      csv << [ "スコア変動", score_change > 0 ? "+#{score_change}" : score_change ]
      csv << []
      csv << [ "動画操作" ]
      csv << [ "一時停止回数", ops[:pause_count] ]
      csv << [ "早送り回数", ops[:forward_seek_count] ]
      csv << [ "巻き戻し回数", ops[:backward_seek_count] ]
      csv << [ "再生速度変更回数", ops[:playback_rate_change_count] ]
      csv << []
      csv << [ "学習行動イベント" ]
      csv << [ "顔未検出回数", face_not_detected ]
      csv << [ "目線停止回数", movement_stop ]
      csv << [ "集中注視回数", center_gaze ]
      csv << [ "問題確認回数", question_confirm ]
      csv << [ "素早い回答回数", quick_response ]
      csv << [ "回答遅延回数", response_delay ]
      csv << [ "メモ入力回数", note_input ]
      csv << []
      csv << [ "問題対応" ]
      csv << [ "問題表示回数", question_display ]
      csv << [ "正解回答数", correct_count ]
      csv << [ "誤答回数", incorrect_count ]
    end

    send_data csv_data, filename: "session_#{learning_session.id}_detail_#{Time.current.strftime('%Y%m%d')}.csv", type: "text/csv; charset=utf-8"
  end

  def export_session_events
    require "csv"

    learning_session = @video.learning_sessions.find(params[:session_id])
    events = learning_session.timestamp_events.order(:timestamp)

    csv_data = "\uFEFF" + CSV.generate(headers: true, encoding: "UTF-8") do |csv|
      csv << [
        "イベント番号", "タイムスタンプ", "セッション経過時間(秒)", "動画再生時間(秒)",
        "イベントタイプ", "説明", "スコア変動", "累積スコア", "追加データ"
      ]

      cumulative_score = 20

      events.each_with_index do |event, index|
        # スコア変動を計算
        score_change = 0
        if event.additional_data.is_a?(Hash) && event.additional_data["scoreChange"]
          score_change = event.additional_data["scoreChange"]
          cumulative_score += score_change
        elsif event.additional_data.is_a?(String)
          begin
            data = JSON.parse(event.additional_data)
            if data["scoreChange"]
              score_change = data["scoreChange"]
              cumulative_score += score_change
            end
          rescue JSON::ParserError
            # JSONパースエラーは無視
          end
        end

        additional_data_str = event.additional_data.is_a?(Hash) ? event.additional_data.to_json : event.additional_data.to_s

        csv << [
          index + 1,
          event.timestamp.strftime("%Y-%m-%d %H:%M:%S.%L"),
          event.session_elapsed&.round(1) || 0,
          event.video_time&.round(1) || 0,
          event.event_type,
          event.description,
          score_change != 0 ? (score_change > 0 ? "+#{score_change}" : score_change) : "",
          cumulative_score,
          additional_data_str
        ]
      end
    end

    send_data csv_data, filename: "session_#{learning_session.id}_events_#{Time.current.strftime('%Y%m%d')}.csv", type: "text/csv; charset=utf-8"
  end

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
        additional = e.additional_data
        additional = JSON.parse(additional) if additional.is_a?(String)

        {
          time: e.session_elapsed,
          score: e.concentration_score,
          change: additional&.dig("scoreChange") || 0,
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

  def prepare_analytics_chart_data
    # 全タイムスタンプイベントを取得（この動画のセッションのみ）
    all_events = @learning_sessions.where(video_id: @video.id)
                                   .joins(:timestamp_events)
                                   .includes(:timestamp_events, :user)
                                   .flat_map(&:timestamp_events)

    # 1. 集中スコア推移データ（セッション別）
    @score_timeline_data = @learning_sessions.where(video_id: @video.id).map do |session|
      events = session.timestamp_events.where.not(concentration_score: nil).order(:session_elapsed)
      {
        label: "#{session.user.email.split('@').first} (#{session.session_start_time.strftime('%m/%d')} ID:#{session.id})",
        data: events.map { |e| { x: e.session_elapsed.round(1), y: e.concentration_score, video_time: e.video_time } },
        session_id: session.id
      }
    end.select { |data| data[:data].any? }

    # 1-2. 動画操作マーカーデータ（セッション別）
    @video_operations_markers = @learning_sessions.where(video_id: @video.id).map do |session|
      video_events = session.timestamp_events
                           .where("event_type LIKE ?", "%video%")
                           .where.not(video_time: nil)
                           .order(:session_elapsed)

      pause_events = video_events.select { |e| e.event_type&.include?("pause") }
      skip_events = video_events.select { |e| e.event_type&.include?("skip") || e.event_type&.include?("seek") }
      other_events = video_events.reject { |e| e.event_type&.include?("pause") || e.event_type&.include?("skip") || e.event_type&.include?("seek") }

      {
        session_id: session.id,
        label: "#{session.user.email.split('@').first} (#{session.session_start_time.strftime('%m/%d')} ID:#{session.id})",
        pause: pause_events.map { |e| { x: e.session_elapsed.round(1), y: e.video_time, description: e.description } },
        skip: skip_events.map { |e| { x: e.session_elapsed.round(1), y: e.video_time, description: e.description } },
        other: other_events.map { |e| { x: e.session_elapsed.round(1), y: e.video_time, description: e.description } }
      }
    end

    # 2. イベントタイプ別分布データ
    event_counts = all_events.group_by(&:event_category).transform_values(&:count)
    @event_distribution_data = {
      labels: event_counts.keys.map(&:humanize),
      values: event_counts.values,
      colors: {
        "score" => "#28a745",
        "video" => "#6610f2",
        "interaction" => "#20c997",
        "question" => "#fd7e14",
        "other" => "#6c757d"
      }
    }

    # 3. 時間帯別活動量データ
    hourly_events = all_events.group_by { |e| e.timestamp.hour }
    @hourly_activity_data = {
      labels: (0..23).to_a,
      values: (0..23).map { |hour| hourly_events[hour]&.count || 0 }
    }

    # 4. ユーザー別平均スコアデータ
    user_scores = @learning_sessions.where(video_id: @video.id).group_by(&:user).map do |user, sessions|
      scores = sessions.map(&:final_score).compact
      {
        user: user.email.split("@").first,
        avg_score: scores.any? ? (scores.sum.to_f / scores.length).round(1) : 0,
        session_count: sessions.count
      }
    end.sort_by { |data| -data[:avg_score] }

    @user_score_data = {
      labels: user_scores.map { |d| d[:user] },
      values: user_scores.map { |d| d[:avg_score] },
      counts: user_scores.map { |d| d[:session_count] }
    }

    # 5. 動画時間 vs イベント密度データ
    video_time_events = all_events.select { |e| e.video_time && e.video_time > 0 }
    time_buckets = video_time_events.group_by { |e| (e.video_time / 30).floor * 30 } # 30秒単位
    @video_time_density_data = time_buckets.map do |time, events|
      {
        x: time,
        y: events.count,
        label: "#{time}s - #{time + 30}s"
      }
    end.sort_by { |d| d[:x] }

    # 6. 動画操作マップデータ（一時停止・スキップの位置）
    video_operations = all_events.select { |e|
      e.event_category == "video" &&
      e.video_time &&
      e.video_time > 0 &&
      (e.event_type&.include?("pause") || e.event_type&.include?("seek") || e.event_type&.include?("skip"))
    }

    # 全体の動画操作マップ
    operation_buckets = video_operations.group_by { |e| (e.video_time / 10).floor * 10 } # 10秒単位
    @video_operations_map_data = operation_buckets.map do |time, events|
      pause_count = events.count { |e| e.event_type&.include?("pause") }
      seek_count = events.count { |e| e.event_type&.include?("seek") || e.event_type&.include?("skip") }
      minutes = time / 60
      seconds = (time % 60).to_s.rjust(2, "0")
      {
        time: time,
        label: "#{minutes}:#{seconds}",
        pause: pause_count,
        seek: seek_count,
        total: events.count
      }
    end.sort_by { |d| d[:time] }

    # ユーザー別の動画操作マップ
    @user_operations_map_data = @learning_sessions.where(video_id: @video.id).map do |session|
      # メモリ上でフィルタリング（event_categoryはメソッドなのでSQLでは使えない）
      user_ops = session.timestamp_events
                        .where.not(video_time: nil)
                        .where("video_time > 0")
                        .where("event_type LIKE ? OR event_type LIKE ? OR event_type LIKE ?",
                               "%pause%", "%seek%", "%skip%")
                        .select { |e| e.event_type&.match?(/video/i) }

      next nil if user_ops.empty?

      ops_by_time = user_ops.group_by { |e| (e.video_time / 10).floor * 10 }
      {
        label: "#{session.user.email.split('@').first} (#{session.session_start_time.strftime('%m/%d %H:%M')} ID:#{session.id})",
        session_id: session.id,
        data: ops_by_time.map do |time, events|
          {
            x: time,
            y: events.count,
            pause: events.count { |e| e.event_type&.include?("pause") },
            seek: events.count { |e| e.event_type&.include?("seek") || e.event_type&.include?("skip") }
          }
        end.sort_by { |d| d[:x] }
      }
    end.compact
  end

  # CSV Export Methods
  def export_summary
    require "csv"

    # 統計データを計算（analyticsアクションと同じロジック）
    questions = @video.questions.includes(:user_responses, :options).order(:time_position)
    user_responses = @video.user_responses.includes(:user, :question).order(:created_at)
    learning_sessions = @video.learning_sessions.includes(:user, :timestamp_events).order(:session_start_time)

    total_responses = user_responses.count
    unique_users = user_responses.joins(:user).distinct.count(:user_id)
    correct_responses = user_responses.where(is_correct: true).count
    accuracy_rate = total_responses > 0 ? (correct_responses.to_f / total_responses * 100).round(1) : 0

    total_sessions = learning_sessions.count
    completed_sessions = learning_sessions.where.not(session_end_time: nil).count

    completed = learning_sessions.where.not(session_end_time: nil)
    if completed.any?
      durations = completed.map { |s| (s.session_end_time - s.session_start_time).to_i }
      average_duration = (durations.sum.to_f / durations.length / 60).round(1)
    else
      average_duration = 0
    end

    average_score = learning_sessions.where.not(final_score: nil).average(:final_score)&.round(1) || 0

    # 動画操作統計
    valid_sessions = learning_sessions.where.not(session_end_time: nil).select { |s| s.duration >= 60 }
    if valid_sessions.any?
      total_pause = valid_sessions.sum { |s| s.video_operation_stats[:pause_count] }
      total_forward = valid_sessions.sum { |s| s.video_operation_stats[:forward_seek_count] }
      total_backward = valid_sessions.sum { |s| s.video_operation_stats[:backward_seek_count] }
      total_rate = valid_sessions.sum { |s| s.video_operation_stats[:playback_rate_change_count] }

      avg_pause = (total_pause.to_f / valid_sessions.count).round(1)
      avg_forward = (total_forward.to_f / valid_sessions.count).round(1)
      avg_backward = (total_backward.to_f / valid_sessions.count).round(1)
      avg_rate = (total_rate.to_f / valid_sessions.count).round(1)
    else
      avg_pause = avg_forward = avg_backward = avg_rate = 0
    end

    csv_data = "\uFEFF" + CSV.generate(headers: true, encoding: "UTF-8") do |csv|
      csv << [ "項目", "値" ]
      csv << [ "動画タイトル", @video.title ]
      csv << [ "分析日時", Time.current.strftime("%Y-%m-%d %H:%M:%S") ]
      csv << []
      csv << [ "基本統計" ]
      csv << [ "総学習セッション数", total_sessions ]
      csv << [ "完了セッション数", completed_sessions ]
      csv << [ "ユニークユーザー数", unique_users ]
      csv << [ "平均セッション時間(分)", average_duration ]
      csv << [ "平均最終スコア", average_score ]
      csv << []
      csv << [ "問題統計" ]
      csv << [ "総問題数", questions.count ]
      csv << [ "総回答数", total_responses ]
      csv << [ "正解数", correct_responses ]
      csv << [ "正解率(%)", accuracy_rate ]
      csv << []
      csv << [ "動画操作統計(1分以上のセッション)" ]
      csv << [ "平均一時停止回数", avg_pause ]
      csv << [ "平均早送り回数", avg_forward ]
      csv << [ "平均巻き戻し回数", avg_backward ]
      csv << [ "平均再生速度変更回数", avg_rate ]
    end

    send_data csv_data, filename: "analytics_summary_#{@video.id}_#{Time.current.strftime('%Y%m%d')}.csv", type: "text/csv; charset=utf-8"
  end

  def export_sessions
    require "csv"

    learning_sessions = @video.learning_sessions.includes(:user, :timestamp_events).order(:session_start_time)

    csv_data = "\uFEFF" + CSV.generate(headers: true, encoding: "UTF-8") do |csv|
      csv << [
        "セッションID", "ユーザー名", "ユーザーID", "開始日時", "終了日時",
        "セッション時間(秒)", "セッション時間(分)", "初期スコア", "最終スコア", "スコア変動",
        "一時停止回数", "早送り回数", "巻き戻し回数", "再生速度変更回数",
        "顔未検出回数", "目線停止回数", "集中注視回数", "問題確認回数",
        "素早い回答回数", "回答遅延回数", "メモ入力回数",
        "問題表示回数", "正解回答数", "誤答回数"
      ]

      learning_sessions.each do |session|
        events = session.timestamp_events
        ops = session.video_operation_stats

        initial_score = 20
        final_score = session.final_score || 0
        score_change = final_score - initial_score

        face_not_detected = events.where("event_type LIKE '%face_not_detected%' OR description LIKE '%顔未検出%'").count
        movement_stop = events.where("event_type LIKE '%movement_stop%' OR description LIKE '%目線停止%'").count
        center_gaze = events.where("event_type LIKE '%center_gaze%' OR description LIKE '%集中注視%'").count
        question_confirm = events.where("event_type LIKE '%question_confirm%' OR description LIKE '%問題確認%'").count
        quick_response = events.where("event_type LIKE '%quick_response%' OR description LIKE '%素早い回答%'").count
        response_delay = events.where("event_type LIKE '%response_delay%' OR description LIKE '%回答遅延%'").count
        note_input = events.where("event_type LIKE '%note%' OR description LIKE '%メモ%'").count
        question_display = events.where("event_type LIKE '%question_display%' OR description LIKE '%問題表示%'").count

        # 問題回答統計
        question_ids = @video.questions.pluck(:id)
        user_responses = UserResponse.where(user: session.user, question_id: question_ids)
        correct_count = user_responses.where(is_correct: true).count
        incorrect_count = user_responses.where(is_correct: false).count

        csv << [
          session.id,
          session.user.email,
          session.user.id,
          session.session_start_time.strftime("%Y-%m-%d %H:%M:%S"),
          session.session_end_time&.strftime("%Y-%m-%d %H:%M:%S") || "進行中",
          session.duration,
          session.duration_in_minutes.round(1),
          initial_score,
          final_score,
          score_change > 0 ? "+#{score_change}" : score_change,
          ops[:pause_count],
          ops[:forward_seek_count],
          ops[:backward_seek_count],
          ops[:playback_rate_change_count],
          face_not_detected,
          movement_stop,
          center_gaze,
          question_confirm,
          quick_response,
          response_delay,
          note_input,
          question_display,
          correct_count,
          incorrect_count
        ]
      end
    end

    send_data csv_data, filename: "sessions_detail_#{@video.id}_#{Time.current.strftime('%Y%m%d')}.csv", type: "text/csv; charset=utf-8"
  end

  def export_events
    require "csv"

    learning_sessions = @video.learning_sessions.includes(:user, :timestamp_events).order(:session_start_time)

    csv_data = "\uFEFF" + CSV.generate(headers: true, encoding: "UTF-8") do |csv|
      csv << [
        "セッションID", "ユーザー名", "イベント番号", "タイムスタンプ",
        "セッション経過時間(秒)", "動画再生時間(秒)", "イベントタイプ", "説明",
        "スコア変動", "累積スコア", "追加データ"
      ]

      learning_sessions.each do |session|
        events = session.timestamp_events.order(:timestamp)
        cumulative_score = 20

        events.each_with_index do |event, index|
          # スコア変動を計算
          score_change = 0
          if event.additional_data.is_a?(Hash) && event.additional_data["scoreChange"]
            score_change = event.additional_data["scoreChange"]
            cumulative_score += score_change
          elsif event.additional_data.is_a?(String)
            begin
              data = JSON.parse(event.additional_data)
              if data["scoreChange"]
                score_change = data["scoreChange"]
                cumulative_score += score_change
              end
            rescue JSON::ParserError
              # JSONパースエラーは無視
            end
          end

          additional_data_str = event.additional_data.is_a?(Hash) ? event.additional_data.to_json : event.additional_data.to_s

          csv << [
            session.id,
            session.user.email,
            index + 1,
            event.timestamp.strftime("%Y-%m-%d %H:%M:%S.%L"),
            event.session_elapsed&.round(1) || 0,
            event.video_time&.round(1) || 0,
            event.event_type,
            event.description,
            score_change != 0 ? (score_change > 0 ? "+#{score_change}" : score_change) : "",
            cumulative_score,
            additional_data_str
          ]
        end
      end
    end

    send_data csv_data, filename: "events_timeline_#{@video.id}_#{Time.current.strftime('%Y%m%d')}.csv", type: "text/csv; charset=utf-8"
  end

  def export_questions
    require "csv"

    questions = @video.questions.includes(:user_responses).order(:time_position)

    csv_data = "\uFEFF" + CSV.generate(headers: true, encoding: "UTF-8") do |csv|
      csv << [
        "問題ID", "問題内容", "表示位置(秒)", "総回答数", "正解数", "誤答数", "正解率(%)"
      ]

      questions.each do |question|
        responses = question.user_responses
        total_count = responses.count
        correct_count = responses.where(is_correct: true).count
        incorrect_count = responses.where(is_correct: false).count
        accuracy = total_count > 0 ? (correct_count.to_f / total_count * 100).round(1) : 0

        csv << [
          question.id,
          question.content.gsub(/\r?\n/, " ").truncate(100),
          question.time_position,
          total_count,
          correct_count,
          incorrect_count,
          accuracy
        ]
      end
    end

    send_data csv_data, filename: "questions_stats_#{@video.id}_#{Time.current.strftime('%Y%m%d')}.csv", type: "text/csv; charset=utf-8"
  end

  def destroy_session
    @session = LearningSession.find(params[:session_id])

    # セッションが存在し、管理権限があることを確認
    if @session && @session.video_id == @video.id
      @session.destroy
      redirect_to video_management_analytics_path(video_id: @video), notice: "学習セッションを削除しました。"
    else
      redirect_to video_management_analytics_path(video_id: @video), alert: "セッションの削除に失敗しました。"
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
