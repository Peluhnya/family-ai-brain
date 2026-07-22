module FamilyBrain
  class AiModelCatalog
    CUSTOM_MODEL_VALUE = "__custom__".freeze

    MODELS = {
      "openai" => [
        { value: "gpt-4o-mini", label: "GPT-4o mini — за замовчуванням, економна та швидка" },
        { value: "gpt-5.4-mini", label: "GPT-5.4 mini — краща якість для сімейного асистента" },
        { value: "gpt-5-nano", label: "GPT-5 nano — найдешевша для простих відповідей" },
        { value: "gpt-5.4", label: "GPT-5.4 — для складніших запитів" },
        { value: "gpt-5.6-luna", label: "GPT-5.6 Luna — новіша швидка модель" }
      ],
      "openai_compatible" => [
        { value: "gpt-4o-mini", label: "GPT-4o mini — якщо підтримується сервісом" },
        { value: "gpt-5-nano", label: "GPT-5 nano — якщо підтримується сервісом" }
      ],
      "ollama" => [
        { value: "gemma3:1b", label: "Gemma 3 1B — найменша й найшвидша" },
        { value: "qwen2.5:3b", label: "Qwen 2.5 3B — баланс швидкості та якості" },
        { value: "llama3.2:3b", label: "Llama 3.2 3B — універсальна локальна модель" }
      ]
    }.freeze

    DEFAULTS = {
      "openai" => "gpt-4o-mini",
      "openai_compatible" => "gpt-4o-mini",
      "ollama" => "gemma3:1b"
    }.freeze

    class << self
      def form_payload
        MODELS.transform_values { |models| models.map(&:dup) }
      end

      def default_for(provider)
        DEFAULTS.fetch(provider.to_s, DEFAULTS.fetch("openai"))
      end

      def known_model?(provider, model)
        MODELS.fetch(provider.to_s, []).any? { |entry| entry.fetch(:value) == model }
      end
    end
  end
end
