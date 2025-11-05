class AddUserRefToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_reference :campaigns, :user, null: false, foreign_key: true
  end
end
