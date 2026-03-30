module FamilyTabCountsBroadcastable
  extend ActiveSupport::Concern

  included do
    class_attribute :family_tab_count_update_fields, default: [].freeze

    after_commit :broadcast_family_tab_counts_after_create_or_destroy, on: %i[create destroy]
    after_commit :broadcast_family_tab_counts_after_update, on: :update
  end

  private

  def broadcast_family_tab_counts_after_create_or_destroy
    broadcast_family_tab_counts
  end

  def broadcast_family_tab_counts_after_update
    return if self.class.family_tab_count_update_fields.empty?
    return unless (previous_changes.keys & self.class.family_tab_count_update_fields.map(&:to_s)).any?

    broadcast_family_tab_counts
  end

  def broadcast_family_tab_counts
    return unless respond_to?(:family) && family.present?

    broadcast_render_later_to [family, :tab_counts],
      partial: "families/tab_counts",
      locals: { family: family }
  end
end
