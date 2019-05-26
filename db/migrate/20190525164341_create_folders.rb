class CreateFolders < ActiveRecord::Migration
  def change
    create_table :folders do |t|
      t.string :name
      t.references :folder, index: true, foreign_key: true

      t.timestamps null: false
    end
    add_index :folders, :name, unique: true
  end
end
