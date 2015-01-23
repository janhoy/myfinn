class AddTotalpriceToApartments < ActiveRecord::Migration
  def change
    add_column :apartments, :totalprice, :integer
  end
end
