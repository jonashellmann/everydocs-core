class CreateStates < ActiveRecord::Migration
  def change
    create_table :states do |t|
      t.string :name
      t.references :user
      t.timestamps null: false
    end
    add_index :states, :name, unique: true
  end
end
