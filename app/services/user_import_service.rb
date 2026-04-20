class UserImportService
  class ImportError < StandardError; end
  class SchemaVersionError < ImportError; end
  class ValidationError < ImportError; end

  SUPPORTED_SCHEMA_VERSIONS = [1].freeze
  MAX_SUPPORTED_VERSION = 1

  attr_reader :dry_run, :errors, :warnings, :imported_data

  def initialize(user, json_data, dry_run: false)
    @user = user
    @json_data = json_data.is_a?(String) ? JSON.parse(json_data) : json_data
    @dry_run = dry_run
    @errors = []
    @warnings = []
    @imported_data = {}
    @name_to_id_map = {
      folders: {},
      tags: {},
      people: {},
      states: {}
    }
  end

  def validate
    @errors = []
    @warnings = []

    begin
      validate_schema_version
      validate_structure
      validate_unique_names
    rescue SchemaVersionError => e
      @errors << e.message
    rescue ImportError => e
      @errors << e.message
    rescue JSON::ParserError => e
      @errors << "Invalid JSON format: #{e.message}"
    end

    @errors.empty?
  end

  def execute
    validate
    return false if @errors.any?

    if @dry_run
      @imported_data[:dry_run] = true
      return true
    end

    import_with_transaction
  end

  private

  def validate_schema_version
    schema_version = @json_data['schema_version']&.to_i

    if schema_version.nil?
      raise SchemaVersionError, 'Missing schema_version'
    end

    if schema_version > MAX_SUPPORTED_VERSION
      raise SchemaVersionError,
        "Unsupported schema_version: #{schema_version}. " \
        "Maximum supported version: #{MAX_SUPPORTED_VERSION}. " \
        "Please update your application to import this data."
    end

    unless SUPPORTED_SCHEMA_VERSIONS.include?(schema_version)
      raise SchemaVersionError, "Unsupported schema_version: #{schema_version}"
    end
  end

  def validate_structure
    data = @json_data['data']
    raise ImportError, 'Missing data section' unless data.is_a?(Hash)

    required_keys = %w[folders tags people states documents]
    required_keys.each do |key|
      unless data[key].is_a?(Array)
        raise ImportError, "Missing or invalid #{key} array"
      end
    end

    data['folders'].each_with_index do |folder, idx|
      unless folder['name'].present?
        raise ImportError, "Folder #{idx}: missing name"
      end
    end

    data['tags'].each_with_index do |tag, idx|
      unless tag['name'].present?
        raise ImportError, "Tag #{idx}: missing name"
      end
    end

    data['people'].each_with_index do |person, idx|
      unless person['name'].present?
        raise ImportError, "Person #{idx}: missing name"
      end
    end

    data['states'].each_with_index do |state, idx|
      unless state['name'].present?
        raise ImportError, "State #{idx}: missing name"
      end
    end

    data['documents'].each_with_index do |doc, idx|
      unless doc['title'].present? && doc['document_date'].present?
        raise ImportError, "Document #{idx}: missing title or document_date"
      end
    end
  end

  def validate_unique_names
    data = @json_data['data']

    folder_names = data['folders'].pluck('name').compact
    if folder_names.uniq.length != folder_names.length
      duplicates = folder_names.tally.select { |_, v| v > 1 }.keys
      raise ImportError, "Duplicate folder names: #{duplicates.join(', ')}"
    end

    tag_names = data['tags'].pluck('name').compact
    if tag_names.uniq.length != tag_names.length
      duplicates = tag_names.tally.select { |_, v| v > 1 }.keys
      raise ImportError, "Duplicate tag names: #{duplicates.join(', ')}"
    end

    person_names = data['people'].pluck('name').compact
    if person_names.uniq.length != person_names.length
      duplicates = person_names.tally.select { |_, v| v > 1 }.keys
      raise ImportError, "Duplicate person names: #{duplicates.join(', ')}"
    end

    state_names = data['states'].pluck('name').compact
    if state_names.uniq.length != state_names.length
      duplicates = state_names.tally.select { |_, v| v > 1 }.keys
      raise ImportError, "Duplicate state names: #{duplicates.join(', ')}"
    end

    check_existing_conflicts(folder_names, tag_names, person_names, state_names)
  end

  def check_existing_conflicts(folder_names, tag_names, person_names, state_names)
    existing_folders = @user.folders.where(name: folder_names).pluck(:name)
    if existing_folders.any?
      @warnings << "Folders already exist and will be skipped: #{existing_folders.join(', ')}"
    end

    existing_tags = @user.tags.where(name: tag_names).pluck(:name)
    if existing_tags.any?
      @warnings << "Tags already exist and will be skipped: #{existing_tags.join(', ')}"
    end

    existing_people = @user.people.where(name: person_names).pluck(:name)
    if existing_people.any?
      @warnings << "People already exist and will be skipped: #{existing_people.join(', ')}"
    end

    existing_states = @user.states.where(name: state_names).pluck(:name)
    if existing_states.any?
      @warnings << "States already exist and will be skipped: #{existing_states.join(', ')}"
    end
  end

  def import_with_transaction
    ActiveRecord::Base.transaction do
      begin
        data = @json_data['data']

        import_folders(data['folders'])
        import_tags(data['tags'])
        import_people(data['people'])
        import_states(data['states'])
        import_documents(data['documents'])

        @imported_data[:completed] = true
        true
      rescue => e
        @errors << "Import failed: #{e.message}"
        raise ActiveRecord::Rollback
      end
    end
  end

  def import_folders(folders_data)
    imported = []
    processed = Set.new

    while processed.size < folders_data.size
      progress = false

      folders_data.each do |folder_data|
        next if processed.include?(folder_data['name'])

        parent_name = folder_data['parent_folder_name']
        if parent_name.nil? || @name_to_id_map[:folders].key?(parent_name)
          existing = @user.folders.find_by(name: folder_data['name'])
          if existing
            @name_to_id_map[:folders][folder_data['name']] = existing.id
            processed.add(folder_data['name'])
            next
          end

          folder = @user.folders.new(
            name: folder_data['name'],
            folder_id: @name_to_id_map[:folders][parent_name],
            created_at: parse_time(folder_data['created_at']),
            updated_at: parse_time(folder_data['updated_at'])
          )

          if folder.save
            @name_to_id_map[:folders][folder_data['name']] = folder.id
            imported << folder_data['name']
            progress = true
          else
            raise ImportError, "Failed to create folder '#{folder_data['name']}': #{folder.errors.full_messages.join(', ')}"
          end

          processed.add(folder_data['name'])
        end
      end

      unless progress
        remaining = folders_data.reject { |f| processed.include?(f['name']) }.pluck('name')
        raise ImportError, "Cannot resolve folder dependencies: #{remaining.join(', ')}"
      end
    end

    @imported_data[:folders] = imported.size
  end

  def import_tags(tags_data)
    imported = []

    tags_data.each do |tag_data|
      existing = @user.tags.find_by(name: tag_data['name'])
      if existing
        @name_to_id_map[:tags][tag_data['name']] = existing.id
        next
      end

      tag = @user.tags.new(
        name: tag_data['name'],
        color: tag_data['color'],
        created_at: parse_time(tag_data['created_at']),
        updated_at: parse_time(tag_data['updated_at'])
      )

      if tag.save
        @name_to_id_map[:tags][tag_data['name']] = tag.id
        imported << tag_data['name']
      else
        raise ImportError, "Failed to create tag '#{tag_data['name']}': #{tag.errors.full_messages.join(', ')}"
      end
    end

    @imported_data[:tags] = imported.size
  end

  def import_people(people_data)
    imported = []

    people_data.each do |person_data|
      existing = @user.people.find_by(name: person_data['name'])
      if existing
        @name_to_id_map[:people][person_data['name']] = existing.id
        next
      end

      person = @user.people.new(
        name: person_data['name'],
        created_at: parse_time(person_data['created_at']),
        updated_at: parse_time(person_data['updated_at'])
      )

      if person.save
        @name_to_id_map[:people][person_data['name']] = person.id
        imported << person_data['name']
      else
        raise ImportError, "Failed to create person '#{person_data['name']}': #{person.errors.full_messages.join(', ')}"
      end
    end

    @imported_data[:people] = imported.size
  end

  def import_states(states_data)
    imported = []

    states_data.each do |state_data|
      existing = @user.states.find_by(name: state_data['name'])
      if existing
        @name_to_id_map[:states][state_data['name']] = existing.id
        next
      end

      state = @user.states.new(
        name: state_data['name'],
        created_at: parse_time(state_data['created_at']),
        updated_at: parse_time(state_data['updated_at'])
      )

      if state.save
        @name_to_id_map[:states][state_data['name']] = state.id
        imported << state_data['name']
      else
        raise ImportError, "Failed to create state '#{state_data['name']}': #{state.errors.full_messages.join(', ')}"
      end
    end

    @imported_data[:states] = imported.size
  end

  def import_documents(documents_data)
    imported = 0

    documents_data.each do |doc_data|
      folder_id = @name_to_id_map[:folders][doc_data['folder_name']]
      state_id = @name_to_id_map[:states][doc_data['state_name']]
      person_id = @name_to_id_map[:people][doc_data['person_name']]

      tag_ids = doc_data['tag_names'].to_a.map do |tag_name|
        @name_to_id_map[:tags][tag_name]
      end.compact

      encrypted_flag = doc_data['encrypted_flag'] || false

      doc = @user.documents.new(
        title: doc_data['title'],
        description: doc_data['description'],
        document_date: parse_date(doc_data['document_date']),
        version: doc_data['version'],
        folder_id: folder_id,
        state_id: state_id,
        person_id: person_id,
        encrypted_flag: encrypted_flag,
        document_url: "imported_#{SecureRandom.uuid}",
        created_at: parse_time(doc_data['created_at']),
        updated_at: parse_time(doc_data['updated_at'])
      )

      if encrypted_flag
        doc.document_text = ''
      else
        doc.document_text = doc_data['document_text']
      end

      if doc.save
        tag_ids.each do |tag_id|
          Documenttag.create(document_id: doc.id, tag_id: tag_id)
        end
        imported += 1
      else
        raise ImportError, "Failed to create document '#{doc_data['title']}': #{doc.errors.full_messages.join(', ')}"
      end
    end

    @imported_data[:documents] = imported
  end

  def parse_time(value)
    return Time.current if value.nil?

    Time.parse(value.to_s) rescue Time.current
  end

  def parse_date(value)
    return Date.today if value.nil?

    Date.parse(value.to_s) rescue Date.today
  end
end
