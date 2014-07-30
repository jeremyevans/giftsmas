unless defined?(RSPEC_EXAMPLE_GROUP)
  if defined?(RSpec)
    require 'rspec/version'
    if RSpec::Version::STRING >= '2.11.0'
      RSpec.configure do |config|
        config.expect_with :rspec do |c|
          c.syntax = :should
        end
        config.mock_with :rspec do |c|
          c.syntax = :should
        end
        if defined?(Capybara)
          config.after(:each) do |example|
            Capybara.reset_sessions!
            Capybara.use_default_driver
          end
        end
        config.around(:each) do |example|
          DB.transaction(:rollback=>:always){example.run}
        end
      end
    end
    RSPEC_EXAMPLE_GROUP = RSpec::Core::ExampleGroup
  else
    RSPEC_EXAMPLE_GROUP = Spec::Example::ExampleGroup
    RSPEC_EXAMPLE_GROUP.class_eval do
      if defined?(Capybara)
        after do
          Capybara.reset_sessions!
          Capybara.use_default_driver
        end
      end

      def execute(*args, &block)
        result = nil
        Sequel::Model.db.transaction(:rollback=>:always){result = super(*args, &block)}
        result
      end
    end
  end
end
