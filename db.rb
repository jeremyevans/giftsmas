Encoding.default_internal = Encoding.default_external = 'UTF-8'

begin
  require_relative '.env'
rescue LoadError
end

require 'sequel/core'

module Giftsmas
unless defined?(GIFTSMAS_ENV)
GIFTSMAS_ENV = ENV['GIFTSMAS_TEST'] ? :test : :production
end

DB = Sequel.connect(ENV.delete('GIFTSMAS_DATABASE_URL') || ENV.delete('DATABASE_URL') || "postgres:///giftsmas#{'_test' if GIFTSMAS_ENV != :production}")
end
