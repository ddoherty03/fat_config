# frozen_string_literal: true

require 'active_support/core_ext/hash'
require 'fileutils'
require 'psych'
require 'tomlib'
require 'inifile'
require 'json'

require_relative "fat_config/version"
require_relative "hash_ext"
require_relative "fat_config/reader"
require_relative "fat_config/styles"

module FatConfig
  class Error < StandardError; end
  # Your code goes here...
end
