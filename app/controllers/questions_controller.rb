class QuestionsController < ApplicationController
  before_action :set_video
  before_action :set_question, only: [:update, :destroy]

  def create
    @question = @video.questions.new(question_params)
    
    if @question.save
      if @question.question_type == 'multiple_choice' && params[:options].present?
        params[:options].each do |option|
          @question.options.create(
            content: option[:content],
            is_correct: option[:is_correct]
          )
        end
      end
      
      redirect_to edit_video_path(@video), notice: 'Question was successfully added.'
    else
      redirect_to edit_video_path(@video), alert: 'Failed to add question.'
    end
  end

  def update
    if @question.update(question_params)
      # Update options if this is a multiple-choice question
      if @question.question_type == 'multiple_choice' && params[:options].present?
        # Delete existing options first
        @question.options.destroy_all
        
        # Create new options
        params[:options].each do |option|
          @question.options.create(
            content: option[:content],
            is_correct: option[:is_correct]
          )
        end
      end
      
      redirect_to edit_video_path(@video), notice: 'Question was successfully updated.'
    else
      redirect_to edit_video_path(@video), alert: 'Failed to update question.'
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
    params.require(:question).permit(:content, :answer, :question_type, :time_position)
  end
end
