require "rake"
require "rake/clean"
require "spec/rake/spectask"

CLEAN.include ["spec/unicorn.log"]

task :default=>[:spec, :integration]

desc "Run unit tests"
Spec::Rake::SpecTask.new("spec") do |t|
  t.spec_files = ["spec/unit.rb"]
end

desc "Run integration tests"
task :integration do
  ENV['GIFTSMAS_TEST'] = '1'
  sh %{echo > spec/unicorn.log}
  sh %{#{FileUtils::RUBY} -S unicorn -c spec/unicorn.conf -D}
  begin
    sleep 1
    sh %{#{FileUtils::RUBY} -S spec spec/integration.rb}
  ensure
    sh %{kill `cat spec/unicorn.pid`}
  end
end
