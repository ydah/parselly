# frozen_string_literal: true

require_relative "lib/parsel/version"

Gem::Specification.new do |spec|
  spec.name = "parsel"
  spec.version = Parsel::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "Pure Ruby CSS selector parser."
  spec.description = "Parsel is a pure Ruby CSS selector parser. Provides a simple and easy-to-use API for parsing CSS selectors."
  spec.homepage = 'https://github.com/ydah/parsel'
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['documentation_uri']     = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/releases"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
