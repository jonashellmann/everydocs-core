class CreateDocumenttags < ActiveRecord::Migration[4.2]
  def change
    create_table :documenttags do |t|
      t.references :document, index: true, foreign_key: true
      t.references :tag, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
