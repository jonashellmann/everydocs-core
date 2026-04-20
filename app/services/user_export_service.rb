class UserExportService
  SCHEMA_VERSION = 1

  def initialize(user)
    @user = user
  end

  def export
    {
      schema_version: SCHEMA_VERSION,
      exported_at: Time.current.iso8601,
      user: {
        name: @user.name,
        email: @user.email
      },
      data: {
        folders: export_folders,
        tags: export_tags,
        people: export_people,
        states: export_states,
        documents: export_documents
      }
    }
  end

  def export_as_json
    export.to_json
  end

  private

  def export_folders
    folders = @user.folders.order(:created_at)
    folders.map do |folder|
      {
        name: folder.name,
        parent_folder_name: folder.folder&.name,
        created_at: folder.created_at.iso8601,
        updated_at: folder.updated_at.iso8601
      }
    end
  end

  def export_tags
    tags = @user.tags.order(:created_at)
    tags.map do |tag|
      {
        name: tag.name,
        color: tag.color,
        created_at: tag.created_at.iso8601,
        updated_at: tag.updated_at.iso8601
      }
    end
  end

  def export_people
    people = @user.people.order(:created_at)
    people.map do |person|
      {
        name: person.name,
        created_at: person.created_at.iso8601,
        updated_at: person.updated_at.iso8601
      }
    end
  end

  def export_states
    states = @user.states.order(:created_at)
    states.map do |state|
      {
        name: state.name,
        created_at: state.created_at.iso8601,
        updated_at: state.updated_at.iso8601
      }
    end
  end

  def export_documents
    documents = @user.documents.order(:created_at)
    documents.map do |doc|
      doc_data = {
        title: doc.title,
        description: doc.description,
        document_date: doc.document_date.iso8601,
        version: doc.version&.to_s,
        encrypted_flag: doc.encrypted_flag,
        folder_name: doc.folder&.name,
        state_name: doc.state&.name,
        person_name: doc.person&.name,
        tag_names: doc.tags.pluck(:name),
        created_at: doc.created_at.iso8601,
        updated_at: doc.updated_at.iso8601
      }

      unless doc.encrypted_flag
        doc_data[:document_text] = doc.document_text
      end

      doc_data
    end
  end
end
