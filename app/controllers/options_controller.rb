class OptionsController < ApplicationController
  before_action :set_question
  before_action :set_option, only: [ :update, :destroy ]

  def create
    @option = @question.options.new(option_params)

    if @option.save
      redirect_to edit_video_path(@question.video), notice: "Option was successfully added."
    else
      redirect_to edit_video_path(@question.video), alert: "Failed to add option."
    end
  end

  def update
    if @option.update(option_params)
      redirect_to edit_video_path(@question.video), notice: "Option was successfully updated."
    else
      redirect_to edit_video_path(@question.video), alert: "Failed to update option."
    end
  end

  def destroy
    @option.destroy
    redirect_to edit_video_path(@question.video), notice: "Option was successfully deleted."
  end

  private

  def set_question
    @question = Question.find(params[:question_id])
  end

  def set_option
    @option = Option.find(params[:id])
  end

  def option_params
    params.require(:option).permit(:content, :is_correct)
  end
end
