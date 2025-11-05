class CampaignsController < ApplicationController
	before_action :set_list, only: :new

	def new
	@campaign = Campaign.new
	end

	private

	def set_list
	@list = Current.user.lists.find_by(id: params[:list_id])
	redirect_to lists_path, alert: "List not found or unauthorized." unless @list
	end
end
