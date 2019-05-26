class CreateUsergroups < ActiveRecord::Migration
  def change
    create_table :usergroups do |t|
      t.references :user, index: true, foreign_key: true
      t.references :group, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
