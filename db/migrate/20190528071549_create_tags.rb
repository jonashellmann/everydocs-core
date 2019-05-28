class CreateTags < ActiveRecord::Migration
  def change
    create_table :tags do |t|
      t.string :name
      t.references :user
      t.string :color

      t.timestamps null: false
    end
  end
end
