require "rake"
require "rake/clean"
require "spec/rake/spectask"

begin
  begin
    # RSpec 1
    require "spec/rake/spectask"
    spec_class = Spec::Rake::SpecTask
    spec_files_meth = :spec_files=
  rescue LoadError
    # RSpec 2
    require "rspec/core/rake_task"
    spec_class = RSpec::Core::RakeTask
    spec_files_meth = :pattern=
  end

  desc "Run the unit and integration specs"
  task :default=>[:spec, :integration]

  desc "Run unit tests"
  spec_class.new("spec") do |t|
    t.send spec_files_meth, ["spec/unit.rb"]
  end

  desc "Run integration tests"
  spec_class.new("integration") do |t|
    t.send spec_files_meth, ["spec/integration.rb"]
  end
rescue LoadError
  task :default do
    puts "Must install rspec to run the default task (which runs specs)"
  end
end

namespace :assets do
  desc "Precompile the assets"
  task :precompile do
    require './giftsmas'
    Giftsmas.compile_assets
  end
end
