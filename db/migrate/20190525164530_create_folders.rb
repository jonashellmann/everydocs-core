class CreateFolders < ActiveRecord::Migration[4.2]
  def change
    create_table :folders do |t|
      t.string :name
      t.references :folder, index: true, foreign_key: true
      t.references :user, index: true, foreign_key: true

      t.timestamps null: false
    end
    add_index :folders, :name, unique: true
  end
end
