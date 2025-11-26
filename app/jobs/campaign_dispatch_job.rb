class CampaignDispatchJob < ApplicationJob
  # Use the standard queue defined in config/application.rb
  queue_as :default

  def perform(campaign)
    # Reload the campaign to ensure we have the latest version (e.g., status is up-to-date)
    @campaign = campaign.reload
    @list = @campaign.list

    # --- STATUS UPDATE (Will be finalized in Part 7) ---
    # @campaign.update!(status: :sending)
    # ----------------------------------------------------

    # Find subscribers belonging to the campaign's list.
    # We use .find_each to handle huge lists efficiently, batching the database queries.
    @list.subscribers.find_each do |subscriber|

      # IMPORTANT: Use #deliver_later to enqueue the *mailer* job.
      # This delegates the actual email network call to a new, small Active Job.
      CampaignMailer.campaign_email(@campaign, subscriber).deliver_later

    end

    # --- STATUS UPDATE (Will be finalized in Part 7) ---
    # @campaign.update!(status: :sent)
    # ----------------------------------------------------
  end
end
