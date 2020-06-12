ENV['RACK_ENV'] = 'test'
ENV['GIFTSMAS_TEST'] = '1'

begin
  require 'warning'
rescue LoadError
else
  $VERBOSE = true
  Warning.ignore(/warning: setting Encoding\.default_/, File.dirname(__dir__))
  Warning.ignore([:missing_ivar, :method_redefined], File.dirname(__dir__))
  Gem.path.each do |path|
    Warning.ignore([:missing_ivar, :method_redefined, :not_reached], path)
  end
end

ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
gem 'minitest'
require 'minitest/global_expectations/autorun'
require 'minitest/hooks/default'

class Minitest::HooksSpec
  around(:all) do |&block|
    Giftsmas::DB.transaction(:rollback=>:always){super(&block)}
  end

  around do |&block|
    Giftsmas::DB.transaction(:rollback=>:always, :savepoint=>true){super(&block)}
  end

  if defined?(Capybara)
    after do
      Capybara.reset_sessions!
      Capybara.use_default_driver
    end
  end
end
