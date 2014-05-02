require 'geordi/cuc'

module Geordi
  class Test < Thor

    package_name 'test'

    default_command :all

    desc 'all', 'Run all employed tests'
    def all
      invoke :unit
      invoke :rspec
      invoke :cucumber

      success 'Successfully ran tests.'
    end

    desc 'rspec', 'Run RSpec'
    long_desc <<-LONGDESC
    Runs RSpec as you want: RSpec 1&2 detection, bundle exec, rspec_spinner
    detection.
    LONGDESC
    def rspec(*files)
      invoke :bundle_install

      if File.exists?('spec/spec_helper.rb')
        announce 'Running specs'

        if file_containing?('Gemfile', /parallel_tests/) and files.empty?
          note 'All specs at once (using parallel_tests)'
          system! 'bundle exec rake parallel:spec'

        else
          # tell which specs will be run
          if files.empty?
            files << 'spec/'
            note 'All specs in spec/'
          else
            note 'Only: ' + files.join(', ')
          end

          command = ['bundle exec']
          # differentiate RSpec 1/2
          command << (File.exists?('script/spec') ? 'spec -c' : 'rspec')
          command << '-r rspec_spinner -f RspecSpinner::Bar' if file_containing?('Gemfile', /rspec_spinner/)
          command << files.join(' ')

          puts
          system! command.join(' ')
        end
      end
    end

    desc 'cucumber', 'Run Cucumber features'
    long_desc <<-LONGDESC
    Runs Cucumber as you want: bundle exec, cucumber_spinner detection,
    separate Firefox for Selenium, etc.
    LONGDESC
    def cucumber(*files)
      invoke :bundle_install

      if File.directory?('features')
        announce 'Running features'
        Geordi::Cucumber.new.run(files) or fail
      end
    end

    desc 'unit', 'Run Test::Unit'
    def unit
      invoke :bundle_install

      if File.exists?('test/test_helper.rb')
        announce 'Running Test::Unit'
        system! 'bundle exec rake test'
      end
    end

    # CODE DUPLICATION!
    # Instead, CLI#bundle_install should be called. But how?
    desc 'bundle', 'Run bundle install if required', :hide => true
    def bundle_install
      if File.exists?('Gemfile') and !system('bundle check &>/dev/null')
        announce 'Bundling'
        system! 'bundle install'
      end
    end
    
    private
    
    # CODE DUPLICATION!
    # Instead, CLI#system! should be called. But how?
    def system!(*commands)
      # Remove the gem's Bundler environment when running command.
      Bundler.clean_system(*commands) or fail
    end
    
    # CODE DUPLICATION!
    # Instead, CLI#file_containing? should be called. But how?
    def file_containing?(file, regex)
      File.exists?(file) and File.read(file).scan(regex).any?
    end

  end
end
