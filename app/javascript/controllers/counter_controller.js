import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count"]

  connect() {
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.animate()
          this.observer.unobserve(entry.target)
        }
      })
    }, { threshold: 0.1 })

    this.observer.observe(this.element)
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  animate() {
    const target = +this.element.getAttribute('data-target-value')
    const speed = 200
    const counter = this.element

    const updateCount = () => {
      const count = +counter.innerText.replace(/,/g, '')
      const inc = target / speed

      if (count < target) {
        counter.innerText = Math.ceil(count + inc).toLocaleString()
        setTimeout(updateCount, 1)
      } else {
        counter.innerText = target.toLocaleString()
      }
    }
    updateCount()
  }
}
