module FamilyWorkspaceRefreshBroadcastable
  extend ActiveSupport::Concern

  included do
    after_commit :broadcast_family_workspace_refresh, on: %i[create update destroy]
  end

  private

  def broadcast_family_workspace_refresh
    return unless respond_to?(:family) && family.present?

    broadcast_refresh_later_to [family, :workspace]
  end
end
