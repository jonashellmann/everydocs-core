class CreateStates < ActiveRecord::Migration[4.2]
  def change
    create_table :states do |t|
      t.string :name
      t.references :user
      t.timestamps null: false
    end
    add_index :states, :name, unique: true
  end
end
