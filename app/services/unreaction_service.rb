# frozen_string_literal: true

class UnreactionService < BaseService
  include Payloadable

  def call(account, status)
    reaction = EmojiReaction.find_by!(account: account, status: status)

    reaction.destroy!
    create_notification(reaction)
    reaction
  end

  private

  def create_notification(reaction)
    status = reaction.status

    if !status.account.local? && status.account.activitypub?
      ActivityPub::DeliveryWorker.perform_async(build_json(reaction), reaction.account_id, status.account.inbox_url)
    end
  end

  def build_json(reaction)
    Oj.dump(serialize_payload(reaction, ActivityPub::UndoEmojiReactionSerializer))
  end
end
