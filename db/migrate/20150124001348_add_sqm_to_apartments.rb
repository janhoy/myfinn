class AddSqmToApartments < ActiveRecord::Migration
  def change
    add_column :apartments, :sqm, :integer
    add_column :apartments, :price_per_sqm, :integer
  end
end
