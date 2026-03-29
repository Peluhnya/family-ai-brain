class Account < ApplicationRecord
  belongs_to :user
  has_many :families, dependent: :destroy

  encrypts :name, :description

  validates :name, presence: true
  validates :email, presence: true
end
