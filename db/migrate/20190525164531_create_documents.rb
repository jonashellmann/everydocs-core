class CreateDocuments < ActiveRecord::Migration
  def change
    create_table :documents do |t|
      t.string :title
      t.text :description
      t.date :document_date
      t.string :document_url
      t.decimal :version
      t.references :folder, index: true, foreign_key: true
      t.references :user, index: true, foreign_key: true
      t.references :state, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
