# frozen_string_literal: true

require_relative "lib/fat_config/version"

Gem::Specification.new do |spec|
  spec.name = "fat_config"
  spec.version = FatConfig::VERSION
  spec.authors = ["Daniel E. Doherty"]
  spec.email = ["ded@ddoherty.net"]

  spec.summary = "Library to read config from standard XDG or classic locations."
  spec.description = <<~DESC

    This library provides a reader for configuration files, looking for them in places
    designated by (1) a user-set environment variable, (2) in the standard XDG
    locations (e.g., /etc/xdg/app.yml), or (3) in the classical UNIX locations
    (e.g. /etc/app/config.yml or ~/.apprc).  Config files can be written in one of
    YAML, TOML, INI-style, or JSON.  It enforces precedence of user-configs over
    system-level configs, and enviroment or command-line configs over the file-based
    configs.

  DESC
  spec.homepage = "https://github.com/ddoherty.net/fat_config"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ddoherty.net/fat_config"
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "bin"
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "activesupport"
  spec.add_dependency "fat_core", '>= 5.6.1'
  spec.add_dependency "inifile"
  spec.add_dependency "tomlib"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
