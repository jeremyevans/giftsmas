# frozen_string_literal: true
ENV['RACK_ENV'] = 'test'
ENV['GIFTSMAS_TEST'] = '1'
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
