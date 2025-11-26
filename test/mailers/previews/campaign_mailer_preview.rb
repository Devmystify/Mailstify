# test/mailers/previews/campaign_mailer_preview.rb

# Preview all emails at http://localhost:3000/rails/mailers/campaign_mailer
class CampaignMailerPreview < ActionMailer::Preview
  def campaign_email
    # 1. Fetch the Campaign with rich content
    campaign = Campaign.last

    # 2. Fetch or create a sample Subscriber object for context and personalization
    list = campaign.list || List.first
    subscriber = Subscriber.new(
      email: "jane.doe@example.com",
      name: "Jane",
      list: list
    )

    # 3. Pass both objects to the mailer action
    CampaignMailer.campaign_email(campaign, subscriber)
  end
end
