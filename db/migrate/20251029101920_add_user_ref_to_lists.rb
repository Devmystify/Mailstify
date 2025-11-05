class AddUserRefToLists < ActiveRecord::Migration[8.0]
  def change
    add_reference :lists, :user, null: false, foreign_key: true
  end
end
