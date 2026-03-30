import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.scrollToBottom = this.scrollToBottom.bind(this)
    this.scheduleScroll = this.scheduleScroll.bind(this)

    this.observer = new MutationObserver(this.scheduleScroll)
    this.observer.observe(this.element, {
      childList: true,
      subtree: true,
      characterData: true
    })

    this.scheduleScroll()
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }

    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame)
    }
  }

  scheduleScroll() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame)
    }

    this.animationFrame = requestAnimationFrame(this.scrollToBottom)
  }

  scrollToBottom() {
    this.element.scrollTop = this.element.scrollHeight
  }
}
