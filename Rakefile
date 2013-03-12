require "rake"
require "rake/clean"
require "spec/rake/spectask"

task :default=>[:spec, :integration]

desc "Run unit tests"
Spec::Rake::SpecTask.new("spec") do |t|
  t.spec_files = ["spec/unit.rb"]
end

desc "Run integration tests"
task :integration do
  ENV['GIFTSMAS_TEST'] = '1'
  sh %{#{FileUtils::RUBY} -S spec spec/integration.rb}
end
