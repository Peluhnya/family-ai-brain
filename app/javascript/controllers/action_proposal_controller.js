import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["actions", "status"]

  submit() {
    if (this.hasActionsTarget) {
      this.actionsTarget.querySelectorAll("button").forEach((button) => {
        button.disabled = true
        button.classList.add("opacity-60")
      })
    }

    if (this.hasStatusTarget) this.statusTarget.textContent = "…"
  }
}
