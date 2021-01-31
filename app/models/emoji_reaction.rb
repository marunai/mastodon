# frozen_string_literal: true

# == Schema Information
#
# Table name: emoji_reactions
#
#  id               :bigint(8)        not null, primary key
#  account_id       :bigint(8)
#  status_id        :bigint(8)
#  custom_emoji_id  :bigint(8)        optional
#  name             :string           default(""), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class EmojiReaction < ApplicationRecord
  after_commit :queue_publish

  belongs_to :account
  belongs_to :status, inverse_of: :emoji_reactions
  belongs_to :custom_emoji, optional: true

  validates :name, presence: true
  validates_with EmojiReactionValidator

  def queue_publish
    PushUpdateWorker.perform_async(status.account.id, status_id) unless status.destroyed?
    PushUpdateWorker.perform_async(status.account.id, status_id) unless status.destroyed?
  end
end
