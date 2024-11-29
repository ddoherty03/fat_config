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
  class Style
    # def merge_files(sys_files = [], usr_files = [], verbose: false, permitted_classes: [])
    #   hash = {}
    #   files = (sys_files + usr_files).compact
    #   files.each do |f|
    #     next unless File.readable?(f)

    #     yml_hash =
    #       if permitted_classes
    #         Psych.safe_load(File.read(f), permitted_classes:)
    #       else
    #         Psych.safe_load(File.read(f))
    #       end
    #     next unless yml_hash

    #     if yml_hash.is_a?(Hash)
    #       yml_hash = yml_hash.methodize
    #     else
    #       raise "Error loading file #{f}:\n#{File.read(f)[0..500]}"
    #     end
    #     if verbose
    #       warn "Merging system config from file '#{f}':" if sys_files.include?(f)
    #       warn "Merging user config from file '#{f}':" if usr_files.include?(f)
    #       hash.report_merge(yml_hash)
    #     end
    #     hash.deep_merge!(yml_hash)
    #   end
    #   hash
    # end

    def merge_files(sys_files = [], usr_files = [], verbose: false, permitted_classes: [])
      raise NotImplementedError, "merge_files must be defined in Style subclass"
    end

    def possible_extensions
      ['cfg', 'config']
    end

    # Return a list of possible YAML configuration file basenames where the
    # directory path already DOES NOT include the app_name so that the
    # basename itself must be distingashable as belonging to the app.
    def constrained_base_names(base)
      [base] + possible_extensions.map { |ext| "#{base}.#{ext}" }
    end

    # Return a list of possible YAML configuration file basenames where the
    # directory path already includes the app_name so that it need not be
    # included in the basename itself.
    def dir_constrained_base_names(base)
      constrained_base_names(base) + [ 'config' ] + possible_extensions.map { |ext| "config.#{ext}" }
    end

    # Return a list of possible YAML configuration file basenames as might be
    # placed in the user's home directory as a hidden file, but which need to
    # contain a component of the app_name to distinguish it.
    def dotted_base_names(base)
      [ ".#{base}", ".#{base}rc" ] + possible_extensions.map { |ext| ".#{base}.#{ext}" }
    end
  end
end
