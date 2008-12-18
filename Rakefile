require "rake"
require "rake/clean"
require "spec/rake/spectask"

CLEAN.include ["spec/style.log"]

desc "Run unit tests"
Spec::Rake::SpecTask.new("spec") do |t|
  t.spec_files = ["spec/unit.rb"]
end
task :default=>[:spec]

desc "Run integration tests"
task :integration do
  ENV['GIFTSMAS_TEST'] = '1'
  sh %{echo > spec/style.log}
  sh %{style -c spec/style.yaml start}
  begin
    sleep 1
    sh %{spec spec/integration.rb}
  ensure
    sh %{style -c spec/style.yaml stop}
  end
end
