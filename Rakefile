# Copyright (c) 2012 Piston Cloud Computing, Inc.

$:.unshift(File.expand_path("../../rake", __FILE__))

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __FILE__)

require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "rake"
begin
  require "rspec/core/rake_task"
rescue LoadError
end

begin
  require "bundler_task"
rescue LoadError
end

begin
  require "ci_task"
rescue LoadError
end

gem_helper = Bundler::GemHelper.new(Dir.pwd)

desc "Build CPI gem into the pkg directory"
task "build" do
  gem_helper.build_gem
end

if defined?(BundlerTask)
  BundlerTask.new

  desc "Build and install CPI into system gems"
  task "install" do
    Rake::Task["bundler:install"].invoke
    gem_helper.install_gem
  end
end

if defined?(RSpec)
  namespace :spec do
    desc "Run Unit Tests"
    rspec_task = RSpec::Core::RakeTask.new(:unit) do |t|
      t.pattern = "spec/unit/**/*_spec.rb"
      t.rspec_opts = %w(--format progress --colour)
    end

    if defined?(CiTask)
      CiTask.new do |task|
        task.rspec_task = rspec_task
      end
    end
  end

  desc "Run tests"
  task :spec => %w(spec:unit)
  task :default => :spec
end
