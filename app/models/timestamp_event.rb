class TimestampEvent < ApplicationRecord
  belongs_to :learning_session
  
  # 追加データをJSONとして扱う
  serialize :additional_data, coder: JSON
  
  validates :timestamp, presence: true
  validates :event_type, presence: true
  
  scope :score_changes, -> { where("event_type LIKE '%score%'") }
  scope :video_operations, -> { where("event_type LIKE '%video%'") }
  scope :interactions, -> { where("event_type LIKE '%interaction%'") }
  scope :questions, -> { where("event_type LIKE '%question%' OR event_type LIKE '%answer%'") }
  
  def format_time
    timestamp.strftime("%H:%M:%S")
  end
  
  def format_session_elapsed
    minutes = (session_elapsed / 60).floor
    seconds = (session_elapsed % 60).floor
    "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
  end
  
  def format_video_time
    minutes = (video_time / 60).floor
    seconds = (video_time % 60).floor
    "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
  end
  
  def event_category
    case event_type
    when /score/
      'score'
    when /video/
      'video'
    when /interaction/
      'interaction'
    when /question|answer/
      'question'
    else
      'other'
    end
  end
end
