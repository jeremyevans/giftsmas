Encoding.default_internal = Encoding.default_external = 'UTF-8' if RUBY_VERSION >= '1.9'

require 'rubygems'
require 'bcrypt'
require 'logger'
require 'sequel'

unless defined?(GIFTSMAS_ENV)
GIFTSMAS_ENV = ENV['GIFTSMAS_TEST'] ? :test : :production
end

begin
  require ::File.expand_path('../config',  __FILE__)
rescue LoadError
  DB = Sequel.connect(ENV['GIFTSMAS_DATABASE_URL'] || ENV['DATABASE_URL'] || "postgres:///giftsmas#{'_test' if GIFTSMAS_ENV != :production}")
end

if GIFTSMAS_ENV == :production
  BCRYPT_COST = BCrypt::Engine::DEFAULT_COST
else
  BCRYPT_COST = BCrypt::Engine::MIN_COST
end

Sequel::Model.plugin :prepared_statements
Sequel::Model.plugin :prepared_statements_associations

%w'user event person gift'.each{|x| require ::File.expand_path("../models/#{x}", __FILE__)}
