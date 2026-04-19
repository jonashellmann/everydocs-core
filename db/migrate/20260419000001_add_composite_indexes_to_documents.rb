class AddCompositeIndexesToDocuments < ActiveRecord::Migration[7.1]
  def change
    add_index :documents, [:user_id, :document_date], name: 'index_documents_on_user_id_and_document_date'
    add_index :documents, [:user_id, :folder_id, :document_date], name: 'index_documents_on_user_id_and_folder_id_and_document_date'
    add_index :documents, [:user_id, :state_id, :document_date], name: 'index_documents_on_user_id_and_state_id_and_document_date'
    add_index :documents, [:user_id, :person_id, :document_date], name: 'index_documents_on_user_id_and_person_id_and_document_date'
  end
end
