require "rake"
require "rake/clean"

test_flags = '-w' if RUBY_VERSION >= '3'

desc "Run model specs"
task :model_spec do
  sh %{#{FileUtils::RUBY} #{test_flags} spec/unit.rb}
end

desc "Run web specs"
task :web_spec do
  sh %{#{FileUtils::RUBY} #{test_flags} spec/integration.rb}
end

desc "Run model and web specs"
task :default=>[:model_spec, :web_spec]

namespace :assets do
  desc "Precompile the assets"
  task :precompile do
    require './giftsmas'
    Giftsmas::App.compile_assets
  end
end

desc "Annotate Sequel models"
task "annotate" do
  ENV['RACK_ENV'] = 'development'
  require_relative 'models'
  require 'sequel/annotate'
  Sequel::Annotate.annotate(Dir['models/*.rb'], :namespace=>true)
end
