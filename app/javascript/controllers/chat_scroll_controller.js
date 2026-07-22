import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.scrollToBottom = this.scrollToBottom.bind(this)
    this.scheduleScroll = this.scheduleScroll.bind(this)
    this.beforeStreamRender = this.beforeStreamRender.bind(this)
    this.handleScroll = this.handleScroll.bind(this)
    this.isNearBottom = true

    this.observer = new MutationObserver(this.scheduleScroll)
    this.observer.observe(this.element, {
      childList: true,
      subtree: true,
      characterData: true
    })

    document.addEventListener("turbo:before-stream-render", this.beforeStreamRender)
    this.element.addEventListener("scroll", this.handleScroll, { passive: true })
    this.scheduleScroll()
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }

    document.removeEventListener("turbo:before-stream-render", this.beforeStreamRender)
    this.element.removeEventListener("scroll", this.handleScroll)

    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame)
    }
  }

  scheduleScroll() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame)
    }

    this.animationFrame = requestAnimationFrame(() => {
      if (this.preserveHistoryPosition) {
        this.element.scrollTop += this.element.scrollHeight - this.previousScrollHeight
        this.preserveHistoryPosition = false
      } else if (this.isNearBottom) {
        this.scrollToBottom()
      }

      this.previousScrollHeight = this.element.scrollHeight
    })
  }

  beforeStreamRender(event) {
    const stream = event.target
    if (stream.action !== "prepend" || stream.target !== "chat_interactions") return

    this.previousScrollHeight = this.element.scrollHeight
    this.preserveHistoryPosition = true
  }

  handleScroll() {
    this.isNearBottom = this.element.scrollHeight - this.element.scrollTop - this.element.clientHeight < 80
  }

  scrollToBottom() {
    this.element.scrollTop = this.element.scrollHeight
    this.isNearBottom = true
  }
}
