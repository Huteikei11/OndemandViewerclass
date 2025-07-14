class VideosController < ApplicationController
  before_action :set_video, only: [:show, :player, :edit, :update, :destroy]

  def index
    @videos = Video.all
  end

  def show
    @questions = @video.questions.order(:time_position)
  end

  # Player view for watching videos with questions
  def player
    @questions = @video.questions.order(:time_position)
    @notes = @video.notes.order(:time_position)
  end

  def new
    @video = Video.new
  end

  def create
    @video = Video.new(video_params)

    if @video.save
      redirect_to @video, notice: 'Video was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @video.update(video_params)
      redirect_to @video, notice: 'Video was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @video.destroy
    redirect_to videos_path, notice: 'Video was successfully deleted.'
  end

  private

  def set_video
    @video = Video.find(params[:id])
  end

  def video_params
    params.require(:video).permit(:title, :description, :video_file, :pdf_file)
  end
end
