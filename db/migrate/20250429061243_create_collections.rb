class CreateCollections < ActiveRecord::Migration[7.2]
  def change
    create_table :collections do |t|
      t.string :urlImage
      t.string :collectionName

      t.timestamps
    end
  end
end
