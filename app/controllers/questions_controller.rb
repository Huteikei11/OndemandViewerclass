class QuestionsController < ApplicationController
  before_action :set_video
  before_action :set_question, only: [:update, :destroy]

  def create
    @question = @video.questions.new(question_params)
    
    # 問題タイプに応じた回答の処理
    case @question.question_type
    when 'multiple_choice'
      # 選択問題の場合はプレースホルダーとして'multiple_choice'を設定
      @question.answer = 'multiple_choice'
    when 'true_false'
      # 〇×問題の場合、回答が空またはnilなら'○'をデフォルト値として設定
      if @question.answer.blank?
        @question.answer = '○'
      elsif !['○', '×'].include?(@question.answer)
        # 不正な値が設定されていた場合も'○'に修正
        @question.answer = '○'
      end
    when 'free_response'
      # 記述問題の場合、空の回答も許可する（バリデーション回避のため空文字を設定）
      @question.answer = @question.answer.presence || ''
    end
    
    if @question.save
      if @question.question_type == 'multiple_choice' && params[:options].present?
        params[:options].each do |option|
          is_correct = option[:is_correct] == "true"
          @question.options.create(
            content: option[:content],
            is_correct: is_correct
          )
        end
      end
      
      redirect_to edit_video_path(@video), notice: 'Question was successfully added.'
    else
      error_messages = @question.errors.full_messages.join(', ')
      redirect_to edit_video_path(@video), alert: "Failed to add question: #{error_messages}"
    end
  end

  def update
    question_attributes = question_params.dup
    
    # 問題タイプに応じた回答の処理
    case question_attributes[:question_type]
    when 'multiple_choice'
      # 選択問題の場合はプレースホルダーとして'multiple_choice'を設定
      question_attributes[:answer] = 'multiple_choice'
    when 'true_false'
      # 〇×問題の場合、回答が空またはnilなら'○'をデフォルト値として設定
      if question_attributes[:answer].blank?
        question_attributes[:answer] = '○'
      elsif !['○', '×'].include?(question_attributes[:answer])
        # 不正な値が設定されていた場合も'○'に修正
        question_attributes[:answer] = '○'
      end
    when 'free_response'
      # 記述問題の場合、空の回答も許可する（バリデーション回避のため空文字を設定）
      question_attributes[:answer] = question_attributes[:answer].presence || ''
    end
    
    if @question.update(question_attributes)
      # Update options if this is a multiple-choice question
      if @question.question_type == 'multiple_choice' && params[:options].present?
        # Delete existing options first
        @question.options.destroy_all
        
        # Create new options
        params[:options].each do |option|
          is_correct = option[:is_correct] == "true"
          @question.options.create(
            content: option[:content],
            is_correct: is_correct
          )
        end
      end
      
      redirect_to edit_video_path(@video), notice: 'Question was successfully updated.'
    else
      error_messages = @question.errors.full_messages.join(', ')
      redirect_to edit_video_path(@video), alert: "Failed to update question: #{error_messages}"
    end
  end

  def destroy
    @question.destroy
    redirect_to edit_video_path(@video), notice: 'Question was successfully deleted.'
  end

  private
  
  def set_video
    @video = Video.find(params[:video_id])
  end
  
  def set_question
    @question = Question.find(params[:id])
  end
  
  def question_params
    params.require(:question).permit(:content, :answer, :question_type, :time_position, :show_answer)
  end
end
