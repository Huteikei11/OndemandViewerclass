import { Controller } from "@hotwired/stimulus"

// This controller handles video player interactions and question management
export default class extends Controller {
  static targets = ["video", "currentTime", "timePosition"]
  
  connect() {
    if (this.hasVideoTarget) {
      this.videoTarget.addEventListener("timeupdate", this.updateCurrentTime.bind(this))
    }
  }
  
  updateCurrentTime() {
    if (this.hasCurrentTimeTarget) {
      const video = this.videoTarget
      const minutes = Math.floor(video.currentTime / 60)
      const seconds = Math.floor(video.currentTime % 60)
      this.currentTimeTarget.textContent = 
        `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
    }
  }
  
  setCurrentTime() {
    if (this.hasVideoTarget && this.hasTimePositionTarget) {
      this.timePositionTarget.value = Math.floor(this.videoTarget.currentTime)
    }
  }
  
  disconnect() {
    if (this.hasVideoTarget) {
      this.videoTarget.removeEventListener("timeupdate", this.updateCurrentTime.bind(this))
    }
  }
}
