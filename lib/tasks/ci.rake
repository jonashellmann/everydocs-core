namespace :ci do
  desc 'CI health check - verify application loads correctly'
  task health: :environment do
    puts '=' * 60
    puts 'CI Health Check'
    puts '=' * 60
    puts

    checks = []

    checks << {
      name: 'Database Connection',
      check: -> {
        ActiveRecord::Base.connection.execute('SELECT 1')
        true
      }
    }

    checks << {
      name: 'User Model',
      check: -> {
        User.column_names.include?('email') && User.column_names.include?('name')
      }
    }

    checks << {
      name: 'Document Model',
      check: -> {
        Document.column_names.include?('title') && Document.column_names.include?('user_id')
      }
    }

    checks << {
      name: 'Routes Loaded',
      check: -> {
        Rails.application.routes.routes.any?
      }
    }

    checks << {
      name: 'JsonWebToken Available',
      check: -> {
        defined?(JsonWebToken) && JsonWebToken.respond_to?(:encode)
      }
    }

    checks << {
      name: 'Lockbox Available',
      check: -> {
        defined?(Lockbox)
      }
    }

    all_passed = true

    checks.each do |check|
      begin
        passed = check[:check].call
        if passed
          puts "  ✓ #{check[:name]}"
        else
          puts "  ✗ #{check[:name]} - FAILED"
          all_passed = false
        end
      rescue => e
        puts "  ✗ #{check[:name]} - ERROR: #{e.message}"
        all_passed = false
      end
    end

    puts
    puts '=' * 60

    if all_passed
      puts 'Health Check: PASSED ✓'
      puts '=' * 60
      exit 0
    else
      puts 'Health Check: FAILED ✗'
      puts '=' * 60
      exit 1
    end
  end
end
