class CampaignMailer < ApplicationMailer
  # The method name (e.g., campaign_email) must match the template name
  def campaign_email(campaign, subscriber)
    # Store objects for access in the view templates
    @campaign = campaign
    @subscriber = subscriber

    # Use the Campaign's subject line
    mail(
      to: @subscriber.email,
      subject: @campaign.subject,
      from: "Mailstify <noreply@mailstify.com>" # Use your desired sender address
    )
  end
end
