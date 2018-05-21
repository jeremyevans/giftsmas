require_relative 'db'

require 'bcrypt'
require 'logger'

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

%w'user event person gift'.each{|x| require_relative "models/#{x}"}
Model.freeze_descendents
DB.freeze
end
