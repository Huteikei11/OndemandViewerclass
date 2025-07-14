class NotesController < ApplicationController
  before_action :set_video
  before_action :set_note, only: [:update, :destroy]

  def create
    @note = @video.notes.new(note_params)
    
    if @note.save
      respond_to do |format|
        format.html { redirect_to player_video_path(@video), notice: 'Note was successfully created.' }
        format.json { render json: @note, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to player_video_path(@video), alert: 'Failed to create note.' }
        format.json { render json: @note.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @note.update(note_params)
      respond_to do |format|
        format.html { redirect_to player_video_path(@video), notice: 'Note was successfully updated.' }
        format.json { render json: @note, status: :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to player_video_path(@video), alert: 'Failed to update note.' }
        format.json { render json: @note.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @note.destroy
    respond_to do |format|
      format.html { redirect_to player_video_path(@video), notice: 'Note was successfully deleted.' }
      format.json { head :no_content }
    end
  end

  private
  
  def set_video
    @video = Video.find(params[:video_id])
  end
  
  def set_note
    @note = Note.find(params[:id])
  end
  
  def note_params
    params.require(:note).permit(:content, :time_position)
  end
end
