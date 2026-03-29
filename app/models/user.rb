class User < ApplicationRecord
  has_many :accounts, dependent: :destroy
  has_many :member_users, dependent: :destroy
  has_many :family_members, through: :member_users

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
end
