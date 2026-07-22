class Family < ApplicationRecord
  belongs_to :account
  has_many :family_members, dependent: :destroy
  has_many :ai_interactions, dependent: :destroy
  has_many :ai_effects, dependent: :destroy
  has_many :life_logs, dependent: :destroy
  has_many :family_knowledge, dependent: :destroy
  has_many :automation_rules, dependent: :destroy
  has_many :automation_rule_executions, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :calendar_connections, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :reminders, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :member_users, through: :family_members
  has_many :users, through: :member_users
  encrypts :name, :timezone, :locale

  validates :name, presence: true
end
