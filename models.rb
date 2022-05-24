require_relative 'db'

require 'bcrypt'
require 'logger'
require 'sequel'

module Giftsmas
if GIFTSMAS_ENV == :production
  BCRYPT_COST = BCrypt::Engine::DEFAULT_COST
else
  BCRYPT_COST = BCrypt::Engine::MIN_COST
end

Model = Class.new(Sequel::Model)
Model.db = DB
Model.plugin :forme
Model.plugin :subclasses
Model.plugin :prepared_statements
Model.plugin :pg_auto_constraint_validations
Model.plugin :auto_restrict_eager_graph
if ENV['RACK_ENV'] == 'test'
  Model.plugin :forbid_lazy_load
  Model.plugin :instance_specific_default, :warn
end

%w'user event person gift'.each{|x| require_relative "models/#{x}"}
Model.freeze_descendents
DB.freeze
end
