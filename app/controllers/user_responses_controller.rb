class UserResponsesController < ApplicationController
  before_action :set_question

  def create
    @user_response = @question.user_responses.new
    
    # ログインしている場合のみユーザーを設定
    if user_signed_in?
      @user_response.user = current_user
    end
    
    @user_response.response_time = params[:user_response][:response_time].to_i if params[:user_response][:response_time]

    # Check if the answer is correct based on question type
    if @question.question_type == "true_false"
      # 〇×問題の場合
      @user_response.user_answer = params[:user_response][:user_answer]
      @user_response.is_correct = (@user_response.user_answer.to_s.downcase == @question.answer.to_s.downcase)

    elsif @question.question_type == "free_response"
      # 記述問題の場合
      @user_response.user_answer = params[:user_response][:user_answer].to_s.strip

      # 空欄の場合は正解
      if @user_response.user_answer.blank?
        @user_response.is_correct = true
      else
        # 空欄でなければ通常の比較
        @user_response.is_correct = (@user_response.user_answer.downcase == @question.answer.to_s.downcase)
      end

    elsif @question.question_type == "multiple_choice"
      # 選択問題の場合
      option_id = params[:option_id].to_s

      if option_id.present?
        option = @question.options.find_by(id: option_id)
        if option
          @user_response.user_answer = option.content
          @user_response.selected_option_id = option.id
          @user_response.is_correct = option.is_correct
        else
          @user_response.user_answer = "無効な選択"
          @user_response.is_correct = false
        end
      else
        # オプションIDがない場合
        @user_response.user_answer = "選択なし"
        @user_response.is_correct = false
      end
    end

    if @user_response.save
      # 応答データを作成
      response_data = {
        user_response: @user_response,
        correct: @user_response.is_correct,
        show_answer: @question.show_answer,
        response_time: @user_response.response_time_in_seconds
      }

      # 回答を表示する場合は正解情報を含める
      if @question.show_answer
        if @question.question_type == "multiple_choice"
          correct_option = @question.options.find_by(is_correct: true)
          response_data[:correct_answer] = correct_option&.content
        else
          response_data[:correct_answer] = @question.answer
        end
      end

      respond_to do |format|
        format.html { redirect_to player_video_path(@question.video), notice: "Response recorded." }
        format.json {
          response.content_type = "application/json"
          render json: response_data, status: :created
        }
      end
    else
      # デバッグ用にエラー詳細をログに出力
      Rails.logger.error "UserResponse validation errors: #{@user_response.errors.full_messages}"
      
      respond_to do |format|
        format.html { redirect_to player_video_path(@question.video), alert: "Failed to record response." }
        format.json {
          response.content_type = "application/json"
          render json: { 
            errors: @user_response.errors.full_messages,
            debug_info: {
              user_answer: @user_response.user_answer,
              response_time: @user_response.response_time,
              user_id: @user_response.user_id,
              question_id: @user_response.question_id
            }
          }, status: :unprocessable_entity
        }
      end
    end
  end

  private

  def set_question
    @question = Question.find(params[:question_id])
  end

  def user_response_params
    params.require(:user_response).permit(:user_answer)
  end
end
