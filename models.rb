Encoding.default_internal = Encoding.default_external = 'UTF-8' if RUBY_VERSION >= '1.9'
$: << '.'

require 'rubygems'
require 'bcrypt'
require 'logger'
require 'sequel/no_core_ext'

unless defined?(GIFTSMAS_ENV)
GIFTSMAS_ENV = ENV['GIFTSMAS_TEST'] ? :test : :production
end

begin
  load File.join(File.dirname(__FILE__), 'config.rb')
rescue LoadError
  DB = Sequel.connect(ENV['DATABASE_URL'] || "postgres:///giftsmas#{'_test' if GIFTSMAS_ENV != :production}")
end

if GIFTSMAS_ENV == :production
  BCRYPT_COST = BCrypt::Engine::DEFAULT_COST
else
  BCRYPT_COST = BCrypt::Engine::MIN_COST
end

Sequel::Model.plugin :prepared_statements
Sequel::Model.plugin :prepared_statements_associations

%w'user event person gift'.each{|x| require "models/#{x}"}
