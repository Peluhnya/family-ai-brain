class FamilyMember < ApplicationRecord
  belongs_to :family
  has_many :member_users, dependent: :destroy
  has_many :users, through: :member_users
  has_many :assigned_tasks, class_name: "Task", foreign_key: :assigned_to, dependent: :nullify, inverse_of: :assignee
  encrypts :name, :role

  validates :name, presence: true
end
