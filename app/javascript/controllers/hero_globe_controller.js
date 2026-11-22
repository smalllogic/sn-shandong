import { Controller } from "@hotwired/stimulus"
import { GlobeRenderer, GLOBE_RADIUS } from "lib/globe_renderer"

const TAU = 2 * Math.PI
const radians = degrees => degrees * Math.PI / 180
const clamp = (value, min, max) => Math.max(min, Math.min(max, value))
const verticalOffsets = [0, -24, 24, -48, 48, -72, 72, -96, 96]

export default class extends Controller {
  static targets = ["stage", "canvas", "marker", "country", "rotationToggle"]
  static values = { textureUrl: String, pauseLabel: String, playLabel: String }

  connect() {
    this.rotation = { azimuth: radians(17), tilt: radians(25) }
    this.motionPreference = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.paused = this.motionPreference.matches
    this.visible = true
    this.markers = this.markerTargets.map(element => ({
      element,
      code: element.dataset.code,
      latitude: radians(Number(element.dataset.latitude)),
      longitude: radians(Number(element.dataset.longitude)),
      side: Number(element.dataset.side),
      label: element.querySelector("[data-globe-label]"),
      dot: element.querySelector("[data-globe-dot]"),
      line: element.querySelector("[data-globe-line]")
    }))

    this.resizeObserver = new ResizeObserver(() => this.resize())
    this.resizeObserver.observe(this.stageTarget)
    this.visibilityObserver = new IntersectionObserver(([entry]) => {
      this.visible = entry.isIntersecting
      this.updatePlayback()
    })
    this.visibilityObserver.observe(this.stageTarget)
    this.motionChanged = () => {
      this.paused = this.motionPreference.matches
      this.focusTween?.kill()
      this.focusTween = null
      this.updatePlayback()
    }
    this.motionPreference.addEventListener("change", this.motionChanged)
    this.resize()
    this.loadRenderer()
  }

  disconnect() {
    this.release()
  }

  async loadRenderer() {
    const request = Symbol()
    this.loading = request
    try {
      const texture = new Image()
      texture.src = this.textureUrlValue
      const [{ gsap }] = await Promise.all([import("gsap"), texture.decode()])
      if (this.loading !== request) return

      this.renderer = new GlobeRenderer(this.canvasTarget, texture)
      this.gsap = gsap
      this.resize()
      this.stageTarget.dataset.rendering = "webgl"
      this.countryTargets.forEach(button => { button.disabled = false })
      this.rotationToggleTarget.hidden = false
      this.updatePlayback()
    } catch {
      if (this.loading === request) this.useFallback()
    }
  }

  release() {
    this.loading = null
    this.resizeObserver?.disconnect()
    this.visibilityObserver?.disconnect()
    if (this.motionChanged) this.motionPreference.removeEventListener("change", this.motionChanged)
    this.useFallback()
    this.markers?.forEach(marker => { delete marker.element.dataset.visible })
  }

  useFallback() {
    this.spin?.kill()
    this.focusTween?.kill()
    this.spin = null
    this.focusTween = null
    this.renderer?.dispose()
    this.renderer = null
    this.gsap = null
    delete this.stageTarget.dataset.rendering
    this.rotationToggleTarget.hidden = true
    this.selectedCode = null
    this.countryTargets.forEach(button => {
      button.disabled = true
      button.setAttribute("aria-pressed", "false")
    })
    if (this.rotation) {
      this.rotation.azimuth = radians(17)
      this.rotation.tilt = radians(25)
      this.render()
    }
  }

  toggleRotation() {
    this.paused = !this.paused
    if (!this.paused) {
      this.focusTween?.kill()
      this.focusTween = null
    }
    this.updatePlayback()
  }

  focusCountry(event) {
    if (!this.gsap) return
    const code = event.currentTarget.dataset.globeCountry
    const marker = this.markers.find(item => item.code === code)
    if (!marker) return

    this.stageTarget.scrollIntoView({ block: "nearest", behavior: this.motionPreference.matches ? "instant" : "smooth" })
    this.paused = true
    this.selectedCode = code
    this.countryTargets.forEach(button => button.setAttribute("aria-pressed", String(button.dataset.globeCountry === code)))
    this.updatePlayback()
    this.focusTween?.kill()

    const delta = marker.longitude - this.rotation.azimuth
    const nearestTurn = Math.atan2(Math.sin(delta), Math.cos(delta))
    const nextTilt = clamp(marker.latitude, radians(-28), radians(42))
    this.focusTween = this.gsap.to(this.rotation, {
      azimuth: this.rotation.azimuth + nearestTurn,
      tilt: nextTilt,
      duration: this.motionPreference.matches ? 0 : 0.95,
      ease: "power2.inOut",
      onUpdate: () => this.render()
    })
  }

  updatePlayback() {
    if (!this.gsap) return

    this.rotationToggleTarget.textContent = this.paused ? this.playLabelValue : this.pauseLabelValue
    this.rotationToggleTarget.setAttribute("aria-pressed", String(this.paused))
    if (this.paused) {
      this.spin?.kill()
      this.spin = null
      return
    }

    if (!this.spin) {
      this.selectedCode = null
      this.countryTargets.forEach(button => button.setAttribute("aria-pressed", "false"))
      this.spin = this.gsap.to(this.rotation, {
        azimuth: this.rotation.azimuth + TAU,
        duration: 62,
        ease: "none",
        repeat: -1,
        paused: true,
        onUpdate: () => this.render()
      })
    }

    this.spin.paused(!this.visible || document.hidden)
  }

  resize() {
    this.width = this.stageTarget.clientWidth
    this.height = this.stageTarget.clientHeight
    for (const marker of this.markers) {
      marker.labelWidth = marker.label.offsetWidth
      marker.labelHeight = marker.label.offsetHeight
    }
    this.renderer?.resize(this.width, this.height)
    this.render()
  }

  render() {
    if (!this.width || !this.height) return

    const { azimuth, tilt } = this.rotation
    this.renderer?.draw(azimuth % TAU, tilt)
    const radius = Math.min(this.width, this.height) * GLOBE_RADIUS
    const cosTilt = Math.cos(tilt)
    const sinTilt = Math.sin(tilt)
    const points = this.markers.map(marker => {
      // Same projection as the shader so the labels stay attached to the earth.
      const longitude = marker.longitude - azimuth
      const cosLatitude = Math.cos(marker.latitude)
      const north = Math.sin(marker.latitude)
      const forward = cosLatitude * Math.cos(longitude)
      return {
        marker,
        x: this.width / 2 + radius * cosLatitude * Math.sin(longitude),
        y: this.height / 2 - radius * (north * cosTilt - forward * sinTilt),
        depth: north * sinTilt + forward * cosTilt
      }
    })
    const front = points.filter(point => point.depth > 0.10)
    if (this.selectedCode) {
      front.sort((a, b) => Number(b.marker.code === this.selectedCode) - Number(a.marker.code === this.selectedCode))
    }

    const used = []
    const displayed = new Set()
    for (const point of front) {
      const box = this.labelPosition(point, used, front)
      if (box) used.push(box)
      this.positionMarker(point, box)
      displayed.add(point.marker)
    }
    for (const marker of this.markers) {
      if (!displayed.has(marker)) delete marker.element.dataset.visible
    }
  }

  labelPosition({ x, y, marker }, used, points) {
    const width = marker.labelWidth
    const height = marker.labelHeight
    for (const side of [marker.side, -marker.side]) {
      for (const offset of verticalOffsets) {
        const left = clamp(x + (side === 1 ? 13 : -13 - width), 4, this.width - width - 4)
        const top = clamp(y - height / 2 + offset, 4, this.height - height - 4)
        const box = { left, top, right: left + width, bottom: top + height }
        const overlapsLabel = used.some(other => box.left < other.right + 4 && box.right > other.left - 4 &&
          box.top < other.bottom + 4 && box.bottom > other.top - 4)
        const overlapsDot = points.some(point => point.x > box.left - 5 && point.x < box.right + 5 &&
          point.y > box.top - 5 && point.y < box.bottom + 5)
        if (!overlapsLabel && !overlapsDot) return box
      }
    }
    return null
  }

  positionMarker({ x, y, marker }, box) {
    marker.element.dataset.visible = box ? "label" : "dot"
    marker.element.dataset.selected = String(marker.code === this.selectedCode)
    marker.dot.style.transform = `translate(${x}px, ${y}px)`
    if (!box) return

    const endX = Math.abs(x - box.left) < Math.abs(x - box.right) ? box.left : box.right
    const endY = (box.top + box.bottom) / 2
    const dx = endX - x
    const dy = endY - y
    marker.label.style.transform = `translate(${box.left}px, ${box.top}px)`
    marker.line.style.width = `${Math.hypot(dx, dy)}px`
    marker.line.style.transform = `translate(${x}px, ${y}px) rotate(${Math.atan2(dy, dx)}rad)`
  }
}
