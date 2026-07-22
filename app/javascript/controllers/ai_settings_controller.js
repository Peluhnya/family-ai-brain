import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "mode",
    "modeHelp",
    "provider",
    "providerSection",
    "apiKeySection",
    "apiKey",
    "apiKeyHelp",
    "apiBaseSection",
    "apiBase",
    "apiBaseHelp",
    "model",
    "modelHelp",
    "customModelSection",
    "customModel",
    "openaiKeyGuide"
  ]

  static values = {
    models: Object,
    selectedModel: String,
    customModelValue: String,
    apiKeySaved: Boolean
  }

  connect() {
    this.modelsByProvider = {}
    this.refresh({ preserveModel: true })
  }

  modeChanged() {
    this.rememberModel()

    if (this.modeTarget.value === "app_default" || this.modeTarget.value === "chatgpt_account") {
      this.providerTarget.value = "openai"
    }

    this.refresh()
  }

  providerChanged() {
    this.rememberModel()
    this.refresh()
  }

  modelChanged() {
    this.rememberModel()
    this.toggleCustomModel()
    this.updateModelHelp()
  }

  refresh({ preserveModel = false } = {}) {
    const mode = this.modeTarget.value
    const provider = this.effectiveProvider

    this.providerSectionTarget.hidden = mode !== "personal_api_key"
    const showApiKey = mode !== "app_default" && !(mode === "personal_api_key" && provider === "ollama")
    this.apiKeySectionTarget.hidden = !showApiKey
    this.apiKeyTarget.required = showApiKey && !this.apiKeySavedValue
    this.apiBaseSectionTarget.hidden = mode !== "personal_api_key" || provider === "openai"

    const showOpenaiGuide = mode === "chatgpt_account" || (mode === "personal_api_key" && provider === "openai")
    this.openaiKeyGuideTargets.forEach((element) => { element.hidden = !showOpenaiGuide })

    this.updateModeHelp(mode)
    this.updateCredentialHelp(provider)
    this.renderModels(provider, preserveModel)
    this.activeProvider = provider
  }

  renderModels(provider, preserveModel) {
    const models = this.modelsValue[provider] || []
    const previousModel = preserveModel
      ? this.selectedModelValue
      : this.modelsByProvider[provider]
    const selectedModel = previousModel || models[0]?.value || ""

    this.modelTarget.replaceChildren()

    models.forEach(({ value, label }) => {
      this.modelTarget.add(new Option(label, value))
    })

    this.modelTarget.add(new Option("Інша модель — вказати model ID вручну", this.customModelValueValue))

    if (models.some(({ value }) => value === selectedModel)) {
      this.modelTarget.value = selectedModel
    } else if (selectedModel) {
      this.modelTarget.value = this.customModelValueValue
      this.customModelTarget.value = selectedModel
    } else {
      this.modelTarget.selectedIndex = 0
    }

    this.modelsByProvider[provider] = selectedModel
    this.toggleCustomModel()
    this.updateModelHelp()
  }

  rememberModel() {
    const provider = this.activeProvider || this.effectiveProvider
    const selected = this.modelTarget.value === this.customModelValueValue
      ? this.customModelTarget.value.trim()
      : this.modelTarget.value

    if (selected) this.modelsByProvider[provider] = selected
  }

  toggleCustomModel() {
    const custom = this.modelTarget.value === this.customModelValueValue
    this.customModelSectionTarget.hidden = !custom
    this.customModelTarget.disabled = !custom
    this.customModelTarget.required = custom
  }

  updateModeHelp(mode) {
    const messages = {
      app_default: "Використовується ключ власника Family AI Brain, збережений на сервері. Вам потрібно лише вибрати модель.",
      chatgpt_account: "Використовується ваш особистий OpenAI API key. Provider та офіційний API endpoint налаштовуються автоматично.",
      personal_api_key: "Оберіть інший AI-сервіс або локальний Ollama — форма покаже лише потрібні для нього поля."
    }

    this.modeHelpTarget.textContent = messages[mode] || ""
  }

  updateCredentialHelp(provider) {
    const apiKeyMessages = {
      openai: "Обов’язковий персональний OpenAI API key у форматі sk-…",
      openai_compatible: "Вставте API key, виданий вашим AI-сервісом.",
      ollama: "Для локального Ollama ключ зазвичай не потрібен."
    }

    const apiBaseMessages = {
      openai_compatible: "Повна адреса OpenAI-compatible endpoint, зазвичай закінчується на /v1.",
      ollama: "Для локального Ollama залиште поле порожнім або використовуйте http://localhost:11434/v1."
    }

    this.apiKeyHelpTarget.textContent = apiKeyMessages[provider] || ""
    this.apiBaseHelpTarget.textContent = apiBaseMessages[provider] || ""
    this.apiBaseTarget.placeholder = provider === "ollama"
      ? "http://localhost:11434/v1"
      : "https://provider.example.com/v1"
  }

  updateModelHelp() {
    const custom = this.modelTarget.value === this.customModelValueValue
    this.modelHelpTarget.textContent = custom
      ? "Введіть точний model ID, який повертає ваш провайдер."
      : "Назва та технічний model ID будуть збережені автоматично."
  }

  get effectiveProvider() {
    return this.modeTarget.value === "personal_api_key" ? this.providerTarget.value : "openai"
  }
}
