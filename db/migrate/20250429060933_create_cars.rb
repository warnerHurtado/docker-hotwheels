class CreateCars < ActiveRecord::Migration[7.2]
  def change
    create_table :cars do |t|
      t.integer :number
      t.string :urlImage
      t.string :model
      t.string :brand
      t.references :collection, null: false, foreign_key: true

      t.timestamps
    end
  end
end
