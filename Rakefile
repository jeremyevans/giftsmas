require "rake"
require "rake/clean"

desc "Run model specs"
task :model_spec do
  sh %{#{FileUtils::RUBY} spec/unit.rb}
end

desc "Run web specs"
task :web_spec do
  sh %{#{FileUtils::RUBY} spec/integration.rb} if RUBY_VERSION >= '2'
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
