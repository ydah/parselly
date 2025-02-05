# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

namespace "build" do
  desc "build parser from parser.y"
  task :parser do
    sh "bundle exec racc parser.y --embedded -o lib/parser.rb -t --log-file=parser.output"
  end
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test/lib"
  t.test_files = FileList["test/**/test_*.rb"]
end
task :test => "build:parser"

task default: :test
