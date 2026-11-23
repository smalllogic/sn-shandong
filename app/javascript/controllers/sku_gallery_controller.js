import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["gallery", "image", "placeholder", "previewBar", "caption", "restore", "product", "option"]

  connect() {
    this.productUrl = this.imageTarget.getAttribute("src")
    this.productAlt = this.imageTarget.alt
    this.productButton = this.productTargets.find(button => button.getAttribute("aria-pressed") === "true")
  }

  showConfiguration({ currentTarget }) {
    this.previewButton = currentTarget
    const description = currentTarget.dataset.imageDescription
    this.displayImage(currentTarget.dataset.imageUrl, description)
    this.captionTarget.textContent = description
    this.previewBarTarget.hidden = false
    this.updateActiveButtons()

    if (!this.inView(this.imageTarget)) {
      this.galleryTarget.scrollIntoView({ block: "start", behavior: this.scrollBehavior })
      this.restoreTarget.focus({ preventScroll: true })
    }
  }

  showProduct({ currentTarget }) {
    this.productButton = currentTarget
    this.productUrl = currentTarget.dataset.imageUrl
    this.resetPreview()
  }

  restoreProduct() {
    const source = this.previewButton
    this.resetPreview()
    if (!source) return

    if (!this.inView(source)) source.scrollIntoView({ block: "center", behavior: this.scrollBehavior })
    source.focus({ preventScroll: true })
  }

  zoom(event) {
    if (event.pointerType !== "mouse" || this.imageTarget.hidden) return

    const bounds = event.currentTarget.getBoundingClientRect()
    const x = (event.clientX - bounds.left) / bounds.width
    const y = (event.clientY - bounds.top) / bounds.height
    this.imageTarget.style.transformOrigin = `${x * 100}% ${y * 100}%`
    this.imageTarget.style.transform = "scale(2.25)"
  }

  stopZoom() {
    this.imageTarget.style.transform = ""
    this.imageTarget.style.transformOrigin = ""
  }

  resetPreview() {
    this.previewButton = null
    this.displayImage(this.productUrl, this.productAlt)
    this.previewBarTarget.hidden = true
    this.updateActiveButtons()
  }

  displayImage(url, description) {
    this.stopZoom()
    if (url) this.imageTarget.setAttribute("src", url)
    else this.imageTarget.removeAttribute("src")
    this.imageTarget.alt = description
    this.imageTarget.hidden = !url
    this.placeholderTarget.hidden = Boolean(url)
  }

  updateActiveButtons() {
    this.optionTargets.forEach(button => button.setAttribute("aria-pressed", String(button === this.previewButton)))
    this.productTargets.forEach(button => button.setAttribute("aria-pressed", String(!this.previewButton && button === this.productButton)))
  }

  inView(element) {
    const { top, bottom, height } = element.getBoundingClientRect()
    const navigationBottom = document.querySelector('[data-navigation-height-target="bar"]')?.getBoundingClientRect().bottom || 0
    const visibleHeight = Math.min(bottom, window.innerHeight) - Math.max(top, navigationBottom)
    return visibleHeight >= Math.min(height, window.innerHeight - navigationBottom) * 0.75
  }

  get scrollBehavior() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth"
  }
}
