class ViewingHistoryController < ApplicationController
  before_action :authenticate_user!

  def index
    # 現在のユーザーの全ての学習セッションを取得
    @learning_sessions = current_user.learning_sessions
                                     .includes(:video, :timestamp_events)
                                     .order(session_start_time: :desc)
                                     .limit(100)
  end

  def session_detail
    @session = current_user.learning_sessions.find(params[:id])
    @timestamp_events = @session.timestamp_events.order(:session_elapsed)

    # グラフ用データの準備
    @chart_data = prepare_chart_data(@timestamp_events)

    render json: @chart_data
  end

  def export_session_detail
    require "csv"

    learning_session = current_user.learning_sessions.find(params[:id])
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
    question_ids = learning_session.video.questions.pluck(:id)
    user_responses = UserResponse.where(user: current_user, question_id: question_ids)
    correct_count = user_responses.where(is_correct: true).count
    incorrect_count = user_responses.where(is_correct: false).count

    csv_data = "\uFEFF" + CSV.generate(headers: true, encoding: "UTF-8") do |csv|
      csv << [ "セッション詳細情報" ]
      csv << []
      csv << [ "項目", "値" ]
      csv << [ "セッションID", learning_session.id ]
      csv << [ "動画タイトル", learning_session.video.title ]
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

    learning_session = current_user.learning_sessions.find(params[:id])
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

  private

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
      score_changes: events.where("event_type LIKE '%score%'").map { |e|
        additional = e.additional_data
        additional = JSON.parse(additional) if additional.is_a?(String)

        {
          time: e.session_elapsed,
          score: e.concentration_score,
          change: additional&.dig("scoreChange") || 0,
          reason: e.description
        }
      },
      video_operations: events.where("event_type LIKE '%video%'").map { |e|
        {
          time: e.session_elapsed,
          operation: e.event_type,
          description: e.description,
          video_time: e.video_time
        }
      },
      interactions: events.where("event_type LIKE '%interaction%' OR event_type LIKE '%question%' OR event_type LIKE '%note%'").map { |e|
        {
          time: e.session_elapsed,
          type: e.event_type,
          description: e.description
        }
      }
    }
  end
end
