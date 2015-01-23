class AddDebtToApartments < ActiveRecord::Migration
  def change
    add_column :apartments, :debt, :integer
  end
end
