class FamilyMember < ApplicationRecord
  belongs_to :family
  has_many :member_users, dependent: :destroy
  has_many :users, through: :member_users
  encrypts :name

  validates :name, presence: true
end
