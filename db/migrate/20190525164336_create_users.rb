class CreateUsers < ActiveRecord::Migration[4.2]
  def change
    create_table :users do |t|
      t.string :name
      t.string :password_digest
      t.string :email

      t.timestamps null: false
    end
    add_index :users, :email, unique: true
  end
end
