# frozen_string_literal: true

require 'fileutils'
require 'psych'
require 'active_support/core_ext/hash'
require 'tomlib'

require_relative "fat_config/version"
require_relative "hash_ext"
require_relative "fat_config/config"

module FatConfig
  class Error < StandardError; end
  # Your code goes here...
end
