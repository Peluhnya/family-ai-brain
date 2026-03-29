class Family < ApplicationRecord
  belongs_to :account
  has_many :family_members, dependent: :destroy
  has_many :member_users, through: :family_members
  has_many :users, through: :member_users
  encrypts :name

  validates :name, presence: true
end
