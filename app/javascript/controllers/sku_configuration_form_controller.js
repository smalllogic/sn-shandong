import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template"]

  add() {
    const index = String(Date.now()) + String(this.listTarget.children.length)
    const content = this.templateTarget.innerHTML.replaceAll("NEW_OPTION", index)
    this.listTarget.insertAdjacentHTML("beforeend", content)
    this.listTarget.lastElementChild.querySelector("input[type=text]")?.focus()
  }

  remove(event) {
    const row = event.target.closest("[data-option-row]")
    const destroy = row.querySelector("[data-destroy-option]")
    if (row.querySelector('input[name$="[id]"]')) {
      destroy.value = "1"
      row.querySelector("fieldset").disabled = true
      row.hidden = true
    } else {
      row.remove()
    }
    this.element.querySelector('[data-action="sku-configuration-form#add"]')?.focus()
  }
}
