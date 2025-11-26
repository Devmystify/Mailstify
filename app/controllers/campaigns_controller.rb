class CampaignsController < ApplicationController
  # Runs before show, edit, update, destroy to scope the campaign to the user
  before_action :set_campaign, only: %i[ show edit update destroy ]
  # Runs before new and create to set the required @list context
  before_action :set_list_for_context, only: %i[ new create ]

  # GET /campaigns
  def index
    @campaigns = Current.user.campaigns.order(created_at: :desc)
  end

  # GET /campaigns/new
  def new
    # Build campaign through user and list to set foreign keys
    @campaign = Current.user.campaigns.new(list: @list)
  end

  # GET /campaigns/1/edit
  def edit
    # @campaign is set by set_campaign, @list is set from campaign's list
    @list = @campaign.list
  end

  # GET /campaigns/1
  def show
    # @campaign is set by set_campaign
  end

  # POST /campaigns
  def create
    # Build through the user association to enforce multi-tenancy
    @campaign = Current.user.campaigns.new(campaign_params)

    respond_to do |format|
      if @campaign.save
        format.html { redirect_to campaign_url(@campaign), notice: "Campaign draft saved successfully." }
        format.json { render :show, status: :created, location: @campaign }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @campaign.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /campaigns/1
  def update
    respond_to do |format|
      if @campaign.update(campaign_params)
        format.html { redirect_to campaign_url(@campaign), notice: "Campaign updated successfully." }
        format.json { render :show, status: :ok, location: @campaign }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @campaign.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /campaigns/1
  def destroy
    @campaign.destroy!

    respond_to do |format|
      format.html { redirect_to campaigns_url, notice: "Campaign deleted." }
      format.json { head :no_content }
    end
  end

  def send_campaign
    @campaign = Current.user.campaigns.find(params[:id])

    # Basic check: Ensure we have content before enqueuing
    unless @campaign.body.present?
      redirect_to @campaign, alert: "Can't dispatch an empty campaign!" and return
    end

    # The zero-dependency magic line: Enqueue the job!
    CampaignDispatchJob.perform_later(@campaign)

    redirect_to @campaign, notice: "Campaign dispatch job enqueued! Emails will be sent shortly."
  rescue ActiveRecord::RecordNotFound
    redirect_to lists_url, alert: "Campaign not found or unauthorized access."
  end

  private
    # Scopes the Campaign lookup to the current user
    def set_campaign
      @campaign = Current.user.campaigns.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to lists_url, alert: "Campaign not found or unauthorized access."
    end

    # Ensures the target list exists and belongs to the current user before creating a campaign
    def set_list_for_context
      # Requires list_id parameter from the URL (e.g., from the link in lists#show)
      @list = Current.user.lists.find_by(id: params[:list_id] || campaign_params[:list_id])
      redirect_to lists_url, alert: "Target list not found or unauthorized." unless @list
    end

    # Only allow a list of trusted parameters through.
    def campaign_params
      params.require(:campaign).permit(:name, :subject, :list_id, :body)
    end
end
