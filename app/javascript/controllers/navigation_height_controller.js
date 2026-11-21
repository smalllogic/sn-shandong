import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar", "spacer"]

  connect() {
    this.observer = new ResizeObserver(() => {
      this.spacerTarget.style.height = `${this.barTarget.getBoundingClientRect().height}px`
    })
    this.observer.observe(this.barTarget)
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
