class MemberUser < ApplicationRecord
  belongs_to :family_member
  belongs_to :user

  validates :user_id, uniqueness: { scope: :family_member_id }
end
