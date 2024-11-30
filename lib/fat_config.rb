# frozen_string_literal: true

require 'active_support/core_ext/hash'
require 'fileutils'
require 'psych'
require 'tomlib'
require 'inifile'
require 'json'

require_relative "fat_config/version"
require_relative "fat_config/errors"
require_relative "fat_config/core_ext/hash_ext"
require_relative "fat_config/reader"
require_relative "fat_config/style"

module FatConfig
  class Error < StandardError; end
  # Your code goes here...
end
