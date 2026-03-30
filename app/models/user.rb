class User < ApplicationRecord
  has_many :accounts, dependent: :destroy
  has_many :ai_interactions, dependent: :nullify
  has_many :member_users, dependent: :destroy
  has_many :family_members, through: :member_users
  has_many :assigned_tasks, through: :family_members, source: :assigned_tasks

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
end
