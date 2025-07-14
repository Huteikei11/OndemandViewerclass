class UserResponsesController < ApplicationController
  before_action :set_question
  
  def create
    @user_response = @question.user_responses.new(user_response_params)
    
    # Check if the answer is correct
    if @question.question_type == 'true_false' || @question.question_type == 'free_response'
      @user_response.is_correct = (@user_response.user_answer.downcase == @question.answer.downcase)
    elsif @question.question_type == 'multiple_choice'
      # For multiple choice, check if the selected option is correct
      option = @question.options.find_by(id: params[:option_id])
      if option
        @user_response.user_answer = option.content
        @user_response.is_correct = option.is_correct
      end
    end
    
    if @user_response.save
      respond_to do |format|
        format.html { redirect_to player_video_path(@question.video), notice: 'Response recorded.' }
        format.json { render json: { user_response: @user_response, correct: @user_response.is_correct }, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to player_video_path(@question.video), alert: 'Failed to record response.' }
        format.json { render json: @user_response.errors, status: :unprocessable_entity }
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
