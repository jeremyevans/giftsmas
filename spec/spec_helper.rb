gem 'minitest'
require 'minitest/autorun'
require 'minitest/hooks/default'

class Minitest::HooksSpec
  def around_all
    DB.transaction(:rollback=>:always){yield}
  end

  def around
    DB.transaction(:rollback=>:always, :savepoint=>true){yield}
  end

  if defined?(Capybara)
    after do
      Capybara.reset_sessions!
      Capybara.use_default_driver
    end
  end
end
