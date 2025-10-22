class CreateCampaigns < ActiveRecord::Migration[8.0]
  def change
    create_table :campaigns do |t|
      t.string :name
      t.string :subject
      t.references :list, null: false, foreign_key: true

      t.timestamps
    end
  end
end
