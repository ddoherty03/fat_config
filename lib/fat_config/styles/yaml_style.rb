# frozen_string_literal: true

require 'date'

module FatConfig
  # NOTE: from the Psych documentation, some types are 'deserialized',
  # meaning they are converted to Ruby objects.  For example, a value of
  # '10' for a property will be converted to the integer 10.
  #
  # Safely load the yaml string in yaml.  By default, only the
  # following classes are allowed to be deserialized:
  #
  # - TrueClass
  # - FalseClass
  # - NilClass
  # - Integer
  # - Float
  # - String
  # - Array
  # - Hash
  #
  # Recursive data structures are not allowed by Psych by default.  Arbitrary
  # classes can be allowed by adding those classes to the permitted_classes
  # keyword argument.  They are additive.  For example, to allow Date
  # deserialization:
  #
  # Config.read adds Date, etc., to permitted classes, but provides for no others.
  class YAMLStyle < Style
    def load_string(str, top_sym: :config)
      data = Psych.safe_load(
        str,
        symbolize_names: false,
        permitted_classes: [Date, DateTime, Time],
      )
      case data
      when Hash
        data.methodize
      when Array
        { top_sym => data.methodize }
      when NilClass
        {}
      end
    rescue Psych::SyntaxError => ex
      raise FatConfig::ParseError, ex.to_s
    end

    def load_file(file_name)
      top_sym = File.basename(file_name).sub(/\.[^\.]*$/, '').as_sym
      data = Psych.safe_load_file(
        file_name,
        symbolize_names: false,
        permitted_classes: [Date, DateTime, Time],
      )
      case data
      when Hash
        data.methodize
      when Array
        { top_sym => data.methodize }
      when NilClass
        {}
      end
    rescue Psych::SyntaxError => ex
      raise FatConfig::ParseError, ex.to_s
    end

    def possible_extensions
      super + ['yml', 'yaml']
    end
  end
end
