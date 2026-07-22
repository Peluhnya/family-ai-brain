class AutomationRule < ApplicationRecord
  include FamilyTabCountsBroadcastable
  include FamilyWorkspaceRefreshBroadcastable
  self.family_tab_count_update_fields = %i[active]

  TEMPLATES = {
    "daily_ai_note" => "Щоденне AI повідомлення",
    "weekly_ai_note" => "Щотижневе AI повідомлення",
    "monthly_life_log" => "Щомісячний life log",
    "chat_keyword_knowledge" => "Ключове слово -> knowledge",
    "daily_task" => "Щоденна задача",
    "chat_keyword_task" => "Ключове слово -> задача",
    "daily_event" => "Щоденна подія",
    "chat_keyword_event" => "Ключове слово -> подія",
    "daily_reminder" => "Щоденне нагадування",
    "chat_keyword_reminder" => "Ключове слово -> нагадування"
  }.freeze

  belongs_to :family
  has_many :automation_rule_executions, dependent: :destroy

  encrypts :name, :trigger_type, :action_type, :template_key

  validates :name, presence: true
  validates :trigger_type, presence: true
  validates :action_type, presence: true

  scope :active_first, -> { order(active: :desc, created_at: :desc) }

  def template_label
    TEMPLATES[template_key] || template_key || "custom"
  end
end
