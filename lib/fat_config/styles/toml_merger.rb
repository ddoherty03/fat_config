module FatConfig
  class TOMLMerger
    def merge_files(sys_files = [], usr_files = [], verbose: false, permitted_classes: [])
      hash = {}
      files = (sys_files + usr_files).compact
      files.each do |f|
        next unless File.readable?(f)

        toml_hash = Tomlib.load(File.read(f))
        next unless toml_hash

        if toml_hash.is_a?(Hash)
          toml_hash = toml_hash.methodize
        else
          raise "Error loading file #{f}:\n#{File.read(f)[0..500]}"
        end
        if verbose
          warn "Merging system config from file '#{f}':" if sys_files.include?(f)
          warn "Merging user config from file '#{f}':" if usr_files.include?(f)
          hash.report_merge(toml_hash)
        end
        hash.deep_merge!(toml_hash)
      end
      hash
    end

    # Return a list of possible YAML configuration file basenames where the
    # directory path already DOES NOT include the app_name so that the
    # basename itself must be distingashable as belonging to the app.
    def constrained_base_names(app_name)
      [
        app_name,
        "#{app_name}.toml",
        "#{app_name}.cfg",
        "#{app_name}.config"
      ]
    end

    # Return a list of possible TOML configuration file basenames where the
    # directory path already includes the app_name so that it need not be
    # included in the basename itself.
    def dir_constrained_base_names(app_name)
      constrained_base_names(app_name) +
        [
          "config",
          "config.toml",
        ]
    end

    # Return a list of possible TOML configuration file basenames as might be
    # placed in the user's home directory as a hidden file, but which need to
    # contain a component of the app_name to distinguish it.
    def dotted_base_names(app_name)
      [
        ".#{app_name}",
        ".#{app_name}rc",
        ".#{app_name}.toml",
        ".#{app_name}.cfg",
        ".#{app_name}.config"
      ]
    end
  end
end
