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
  # Recursive data structures are not allowed by default.  Arbitrary classes
  # can be allowed by adding those classes to the permitted_classes
  # keyword argument.  They are additive.  For example, to allow Date
  # deserialization:
  #
  # Config.read adds Date, etc., to permitted classes, but provides for no others.
  class YAMLStyle < Style
    def load_file(file_name)
      Psych.safe_load(File.read(file_name), permitted_classes: [Date, DateTime, Time]) || {}
    end

    def possible_extensions
      super + ['yml', 'yaml']
    end
  end
end
