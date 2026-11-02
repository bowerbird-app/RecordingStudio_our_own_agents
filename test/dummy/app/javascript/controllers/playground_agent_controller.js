import { Controller } from "@hotwired/stimulus"

// Shows the tools for the chosen agent and resets skills to that agent's defaults.
export default class extends Controller {
  static targets = ["skills", "profile", "tools"]
  static values = {
    profiles: Object,
    skills: Object
  }

  change(event) {
    if (event.target.name !== "agent") return

    this.apply(event.target.value)
  }

  apply(chosen) {
    this.toolsTargets.forEach((group) => {
      const visible = group.getAttribute("data-playground-tools") === chosen
      group.hidden = !visible
      group.disabled = !visible
    })

    if (this.hasProfileTarget && this.profilesValue[chosen]) {
      this.profileTarget.value = this.profilesValue[chosen]
    }

    const wanted = this.skillsValue[chosen] || []
    if (!this.hasSkillsTarget) return

    this.skillsTarget.querySelectorAll("[role='option']").forEach((option) => {
      const selected = option.getAttribute("aria-selected") === "true"
      const should = wanted.includes(option.getAttribute("data-value"))
      if (selected !== should) option.click()
    })
  }
}
