require "rake"
require "rake/clean"

desc "Run model specs"
task :model_spec do
  sh %{#{FileUtils::RUBY} -I lib spec/unit.rb}
end

desc "Run web specs"
task :web_spec do
  sh %{#{FileUtils::RUBY} -I lib spec/integration.rb}
end

desc "Run model and web specs"
task :default=>[:model_spec, :web_spec]

namespace :assets do
  desc "Precompile the assets"
  task :precompile do
    require './giftsmas'
    Giftsmas.compile_assets
  end
end
