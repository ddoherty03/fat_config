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
  # Config.read passes anything in the ~permitted_classes~ parameter onto Psych.safe_load.
  class YAMLMerger
    def merge_files(files = [], verbose: false, permitted_classes: [])
      hash = {}
      files.each do |f|
        next unless File.readable?(f)

        yml_hash =
          if permitted_classes
            Psych.safe_load(File.read(f), permitted_classes:)
          else
            Psych.safe_load(File.read(f))
          end
        next unless yml_hash

        if yml_hash.is_a?(Hash)
          yml_hash = yml_hash.methodize
        else
          raise "Error loading file #{f}:\n#{File.read(f)[0..500]}"
        end
        yml_hash.report("Merging config from file '#{f}") if verbose
        hash.deep_merge!(yml_hash)
      end
      hash
    end

    def xdg_base_names(app_name)
      [
        app_name.to_s,
        "#{app_name}.yml",
        "#{app_name}.yaml",
        "config.yml",
        "config.yaml",
        "#{app_name}.cfg",
        "#{app_name}.config"
      ]
    end

    def classic_base_names(app_name)
      [
        app_name.to_s,
        "#{app_name}.yml",
        "#{app_name}.yaml",
        "#{app_name}.cfg",
        "#{app_name}.config"
      ]
    end

    def dotted_base_names(app_name)
      [
        ".#{app_name}",
        ".#{app_name}rc",
        ".#{app_name}.yml",
        ".#{app_name}.yaml",
        ".#{app_name}.cfg",
        ".#{app_name}.config"
      ]
    end
  end
end
