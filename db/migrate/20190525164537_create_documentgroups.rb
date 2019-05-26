class CreateDocumentgroups < ActiveRecord::Migration
  def change
    create_table :documentgroups do |t|
      t.references :document, index: true, foreign_key: true
      t.references :group, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
