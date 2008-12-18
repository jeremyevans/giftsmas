require 'rubygems'
require 'digest/sha1'
require 'logger'
require 'sequel'

unless defined?(GIFTSMAS_ENV)
GIFTSMAS_ENV = ENV['GIFTSMAS_TEST'] ? :test : :production
end

begin
  load File.join(File.dirname(__FILE__), 'config.rb')
rescue LoadError
  DB = Sequel.connect("postgres:///giftsmas#{'_test' if GIFTSMAS_ENV != :production}")
end

DB.schema
%w'user event person gift'.each{|x| require "models/#{x}"}
