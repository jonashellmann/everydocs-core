class CreateDocuments < ActiveRecord::Migration[4.2]
  def change
    create_table :documents do |t|
      t.string :title
      t.text :description
      t.date :document_date
      t.string :document_url
      t.decimal :version
      t.references :folder, index: true, foreign_key: {on_delete: :nullify}
      t.references :user, index: true, foreign_key: {on_delete: :cascade}
      t.references :state, index: true, foreign_key: {on_delete: :nullify}
      t.references :person, index: true, foreign_key: {on_delete: :nullify}

      t.timestamps null: false
    end
  end
end
