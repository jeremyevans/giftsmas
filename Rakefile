require "rake"
require "rake/clean"
require "spec/rake/spectask"

CLEAN.include ["spec/style.log"]

task :default=>[:spec, :integration]

desc "Run unit tests"
Spec::Rake::SpecTask.new("spec") do |t|
  t.spec_files = ["spec/unit.rb"]
end

desc "Run integration tests"
task :integration do
  ENV['GIFTSMAS_TEST'] = '1'
  sh %{echo > spec/unicorn.log}
  sh %{unicorn -c spec/unicorn.conf -D}
  begin
    sleep 1
    sh %{spec spec/integration.rb}
  ensure
    sh %{kill `cat spec/unicorn.pid`}
  end
end
