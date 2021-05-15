# frozen_string_literal: true

# == Schema Information
#
# Table name: emoji_reactions
#
#  id              :bigint(8)        not null, primary key
#  account_id      :bigint(8)
#  status_id       :bigint(8)
#  name            :string           default(""), not null
#  custom_emoji_id :bigint(8)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  uri             :string
#

class EmojiReaction < ApplicationRecord
  include Paginable

  belongs_to :account
  belongs_to :status, inverse_of: :emoji_reactions 
  belongs_to :custom_emoji, optional: true

  has_one :notification, as: :activity, dependent: :destroy

  validates :name, presence: true
  validates_with EmojiReactionValidator

  before_validation do
    self.status = status.reblog if status&.reblog?
  end
end
