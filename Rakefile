# frozen_string_literal: true

require 'bundler/gem_tasks'

namespace 'build' do
  desc 'build parser from parser.y'
  task :parser do
    sh 'bundle exec racc parser.y --embedded --frozen -o lib/parselly/parser.rb -t --log-file=parser.output'
  end

  desc 'verify generated parser files are in sync'
  task check_parser: :parser do
    sh 'git diff --exit-code lib/parselly/parser.rb parser.output'
  end
end

desc 'run parser benchmarks'
task :benchmark do
  ruby 'benchmark/parser_benchmark.rb'
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end
task spec: 'build:parser'

task default: :spec
