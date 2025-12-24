# frozen_string_literal: true

require 'active_support/core_ext/hash'
require 'fat_core/all'
require 'fileutils'
require 'psych'
require 'tomlib'
require 'inifile'
require 'json'

# Gem Overview (extracted from README.org by gem_docs)
#
# * Introduction
# Allowing a user to configure an application to change its behavior at runtime
# can be seen as constructing a ruby ~Hash~ that merges settings from a variety
# of sources in a hierarchical fashion: first from system-wide file settings,
# merged with user-level file settings, merged with environment variable
# settings, merged with command-line parameters.  Constructing this Hash, while
# needed by nearly any command-line app, can be a tedious chore, especially when
# there are standards, such as the XDG standards and Unix tradition, that may or
# may not be followed.
#
# ~FatConfig~ eliminates the tedium of reading configuration files and the
# environment to populate a Hash of configuration settings.  You need only
# define a ~FatConfig::Reader~ and call its ~#read~ method to look for, read,
# translate, and merge any config files into a single Hash that encapsulates all
# the files in the proper priority.  It can be set to read ~YAML~, ~TOML~,
# ~JSON~, or ~INI~ config files.
module FatConfig
  class Error < StandardError; end
  require_relative "fat_config/version"
  require_relative "fat_config/errors"
  require_relative "fat_config/core_ext/hash_ext"
  require_relative "fat_config/reader"
  require_relative "fat_config/style"
end
