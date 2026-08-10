class VideosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_video, only: [ :show, :player, :edit, :update, :destroy, :duplicate ]
  before_action :check_video_access, only: [ :player ]
  before_action :check_video_management, only: [ :edit, :update, :destroy, :duplicate ]

  def index
    redirect_to root_path
  end

  def show
    @questions = @video.questions.order(:time_position)
  end

  # Player view for watching videos with questions
  def player
    Rails.logger.info "🎬 player アクション開始 - Video ID: #{@video.id}, User: #{current_user.id}"

    @questions = @video.questions.order(:time_position)
    @user_responses = current_user&.user_responses&.joins(:question)&.where(questions: { video_id: @video.id }) || []

    # セッション復元：視聴実績がある最新セッションを取得
    begin
      @resume_session = current_user.learning_sessions
        .where(video_id: @video.id)
        .where("last_video_time > 0")
        .order(updated_at: :desc)
        .first
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.warn "⚠️ last_video_time カラムが存在しません（session_dataから検索）: #{e.message}"
      # カラム未存在時は session_data の last_video_time をチェック
      @resume_session = current_user.learning_sessions
        .where(video_id: @video.id)
        .order(updated_at: :desc)
        .limit(20)
        .to_a
        .find { |s| s.can_resume? }
    end

    # JavaScript側で復元するために、最新セッション情報をJSON化して渡す
    @latest_session_json = if @resume_session
      begin
        {
          id: @resume_session.id,
          last_video_time: @resume_session.last_video_time_value,
          last_session_elapsed: @resume_session.last_session_elapsed_value,
          formatted_resume_time: @resume_session.formatted_resume_time,
          "can_resume?" => @resume_session.can_resume?
        }.to_json
      rescue => e
        Rails.logger.warn "⚠️ セッション情報のJSON化に失敗: #{e.message}"
        {}.to_json
      end
    else
      {}.to_json
    end

    Rails.logger.info "[再開機能] コントローラー実行 - ユーザー: #{current_user.id}, 動画: #{@video.id}"
    Rails.logger.info "[再開機能] @resume_session: #{@resume_session.present?}"
    if @resume_session
      Rails.logger.info "[再開機能] セッションID: #{@resume_session.id}"
      Rails.logger.info "[再開機能] can_resume?: #{@resume_session.can_resume?}"
    end

    # Render環境でのファイル存在チェック
    if Rails.env.production? && @video.video_file.attached?
      begin
        file_path = ActiveStorage::Blob.service.path_for(@video.video_file.key)
        unless File.exist?(file_path)
          Rails.logger.error "⚠️ 動画ファイルが見つかりません: #{file_path}"
          Rails.logger.error "Video ID: #{@video.id}, Blob key: #{@video.video_file.key}"
        end
      rescue => e
        Rails.logger.error "❌ ActiveStorage path_for エラー: #{e.class} - #{e.message}"
        Rails.logger.error "Video ID: #{@video.id}, Blob key: #{@video.video_file.key}"
      end
    end

    Rails.logger.info "🎬 player アクション完了 - テンプレート描画開始"
  rescue => e
    Rails.logger.error "❌ player アクションでエラー発生: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
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
    update_params = video_params.to_h

    # is_privateの値を確認
    is_private_param = update_params[:is_private]
    is_becoming_private = (is_private_param == "1" || is_private_param == true)

    # パスワードが空の場合の処理
    if update_params[:password].blank?
      # 限定公開に変更する場合で、既存のパスワードがない場合はエラー
      if is_becoming_private && @video.password_digest.blank?
        @video.errors.add(:password, "は限定公開の場合必須です")
        @questions = @video.questions.order(:time_position)
        render :edit, status: :unprocessable_entity
        return
      end
      # パスワードが空の場合は更新しない（既存のパスワードを保持）
      update_params.delete(:password)
    end

    if @video.update(update_params)
      redirect_to edit_video_path(@video), notice: "動画が正常に更新されました。"
    else
      @questions = @video.questions.order(:time_position)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @video.destroy
    redirect_to root_path, notice: "動画が正常に削除されました。"
  end

  def duplicate
    new_video = nil

    ActiveRecord::Base.transaction do
      # ── 動画本体（video_file presence バリデーションを回避するため
      #    先にレコードを作成し、その後ファイルをアタッチする） ────
      new_video = Video.new(
        title:           "#{@video.title}のコピー",
        description:     @video.description,
        is_private:      @video.is_private,
        password_digest: @video.password_digest,
        creator:         current_user
      )
      new_video.save!(validate: false)

      # ── ファイル（同一blobを参照） ─────────────────────────
      new_video.video_file.attach(@video.video_file.blob) if @video.video_file.attached?
      new_video.pdf_file.attach(@video.pdf_file.blob)     if @video.pdf_file.attached?

      # ── 問題・選択肢（IDマッピングを構築） ───────────────────
      # 複製データなのでバリデーションをスキップして保存
      question_id_map = {}
      option_id_map   = {}

      @video.questions.includes(:options).order(:time_position).each do |q|
        new_q = Question.new(
          video_id:         new_video.id,
          content:          q.content,
          answer:           q.answer,
          question_type:    q.question_type,
          time_position:    q.time_position,
          show_answer:      q.show_answer,
          explanation:      q.explanation,
          show_explanation: q.show_explanation
        )
        new_q.save!(validate: false)
        question_id_map[q.id] = new_q.id

        q.options.each do |opt|
          new_opt = Option.new(question_id: new_q.id, content: opt.content, is_correct: opt.is_correct)
          new_opt.save!(validate: false)
          option_id_map[opt.id] = new_opt.id
        end
      end

      # ── 学習セッション（IDマッピングを構築） ──────────────────
      session_id_map = {}
      now = Time.current

      @video.learning_sessions.each do |ls|
        new_ls = LearningSession.new(
          user_id:              ls.user_id,
          video_id:             new_video.id,
          session_start_time:   ls.session_start_time,
          session_end_time:     ls.session_end_time,
          final_score:          ls.final_score,
          total_events:         ls.total_events,
          session_data:         ls.session_data,
          is_active:            false,
          last_video_time:      ls.last_video_time,
          last_session_elapsed: ls.last_session_elapsed,
          paused_at:            ls.paused_at
        )
        new_ls.save!(validate: false)
        session_id_map[ls.id] = new_ls.id
      end

      # ── タイムスタンプイベント（insert_all で一括） ───────────
      if session_id_map.any?
        events_data = TimestampEvent
          .where(learning_session_id: session_id_map.keys)
          .map do |e|
            {
              learning_session_id: session_id_map[e.learning_session_id],
              timestamp:           e.timestamp,
              session_elapsed:     e.session_elapsed,
              video_time:          e.video_time,
              event_type:          e.event_type,
              description:         e.description,
              concentration_score: e.concentration_score,
              video_state:         e.video_state,
              playback_rate:       e.playback_rate,
              additional_data:     e.additional_data,
              created_at:          now,
              updated_at:          now
            }
          end
        TimestampEvent.insert_all(events_data) if events_data.any?
      end

      # ── 解答記録（insert_all で一括） ─────────────────────────
      responses_data = UserResponse
        .joins(:question)
        .where(questions: { video_id: @video.id })
        .filter_map do |ur|
          new_qid = question_id_map[ur.question_id]
          next unless new_qid

          {
            question_id:        new_qid,
            user_id:            ur.user_id,
            user_answer:        ur.user_answer,
            is_correct:         ur.is_correct,
            response_time:      ur.response_time,
            selected_option_id: ur.selected_option_id ? option_id_map[ur.selected_option_id] : nil,
            created_at:         now,
            updated_at:         now
          }
        end
      UserResponse.insert_all(responses_data) if responses_data.any?

      # ── メモ（insert_all で一括） ──────────────────────────
      notes_data = Note.where(video_id: @video.id).map do |note|
        {
          video_id:      new_video.id,
          user_id:       note.user_id,
          content:       note.content,
          time_position: note.time_position,
          created_at:    now,
          updated_at:    now
        }
      end
      Note.insert_all(notes_data) if notes_data.any?

      # ── 管理者・アクセス権（insert_all で一括） ───────────────
      managers_data = @video.video_managers.map do |vm|
        { video_id: new_video.id, user_id: vm.user_id, created_at: now, updated_at: now }
      end
      VideoManager.insert_all(managers_data) if managers_data.any?

      accesses_data = @video.video_accesses.map do |va|
        { video_id: new_video.id, user_id: va.user_id, created_at: now, updated_at: now }
      end
      VideoAccess.insert_all(accesses_data) if accesses_data.any?
    end

    redirect_to edit_video_path(new_video), notice: "「#{@video.title}」を複製しました。"
  rescue => e
    Rails.logger.error "動画複製エラー: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to @video, alert: "複製中にエラーが発生しました: #{e.message}"
  end

  private

  def set_video
    @video = Video.find(params[:id])
  end

  def check_video_access
    return if @video.can_be_accessed_by?(current_user)

    redirect_to video_access_new_path, alert: "この動画にアクセスする権限がありません。"
  end

  def check_video_management
    unless current_user.can_manage_video?(@video)
      redirect_to root_path, alert: "この動画を管理する権限がありません。"
    end
  end

  def video_params
    params.require(:video).permit(:title, :description, :video_file, :pdf_file, :password, :is_private, :duration)
  end
end
