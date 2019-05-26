class CreateGroups < ActiveRecord::Migration
  def change
    create_table :groups do |t|
      t.string :name
      t.references :group, index: true, foreign_key: true

      t.timestamps null: false
    end
    add_index :groups, :name, unique: true
  end
end
