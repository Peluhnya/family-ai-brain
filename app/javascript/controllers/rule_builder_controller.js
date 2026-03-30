import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "section"]

  connect() {
    this.update()
  }

  update() {
    const template = this.templateTarget.value

    this.sectionTargets.forEach((section) => {
      const templates = (section.dataset.templates || "")
        .split(" ")
        .filter(Boolean)

      const visible = templates.includes(template)
      section.classList.toggle("hidden", !visible)
    })
  }
}
