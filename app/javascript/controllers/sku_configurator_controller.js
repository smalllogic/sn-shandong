import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "total"]
  static values = { skuId: Number, locale: String, quoteLabel: String, noSurchargeLabel: String }

  connect() {
    this.refresh()
  }

  refresh() {
    const subtotals = new Map()
    let needsQuote = false
    for (const option of this.selectedOptions) {
      if (option.dataset.surchargeCents === undefined) {
        needsQuote = true
      } else {
        const surcharge = Number(option.dataset.surchargeCents)
        if (surcharge === 0) continue
        const currency = option.dataset.currency
        subtotals.set(currency, (subtotals.get(currency) ?? 0) + surcharge)
      }
    }
    const format = new Intl.NumberFormat(this.localeValue, { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    const amounts = Array.from(subtotals, ([currency, cents]) => `${currency} ${format.format(cents / 100)}`)
    if (needsQuote) amounts.push(this.quoteLabelValue)
    this.totalTarget.textContent = amounts.length ? amounts.join(" + ") : this.noSurchargeLabelValue
  }

  addToQuote() {
    window.addToOrder(this.skuIdValue, this.selectedOptions.map(option => option.value))
  }

  get selectedOptions() {
    return this.optionTargets.filter(option => option.checked && option.value !== "")
  }
}
