module FatConfig
  class INIMerger < Style
    def merge_files(sys_files = [], usr_files = [], verbose: false, permitted_classes: [])
      hash = {}
      files = (sys_files + usr_files).compact
      files.each do |f|
        next unless File.readable?(f)

        ini_hash = IniFile.load(f).to_h
        next unless ini_hash

        if ini_hash.is_a?(Hash)
          ini_hash = ini_hash.methodize
        else
          raise "Error loading file #{f}:\n#{File.read(f)[0..500]}"
        end
        if verbose
          warn "Merging system config from file '#{f}':" if sys_files.include?(f)
          warn "Merging user config from file '#{f}':" if usr_files.include?(f)
          hash.report_merge(ini_hash)
        end
        hash.deep_merge!(ini_hash)
      end
      hash
    end

    def possible_extensions
      super + ['ini']
    end

    # # Return a list of possible YAML configuration file basenames where the
    # # directory path already DOES NOT include the app_name so that the
    # # basename itself must be distingashable as belonging to the app.
    # def constrained_base_names(app_name)
    #   [
    #     app_name,
    #     "#{app_name}.ini",
    #     "#{app_name}.cfg",
    #     "#{app_name}.config"
    #   ]
    # end

    # # Return a list of possible INI configuration file basenames where the
    # # directory path already includes the app_name so that it need not be
    # # included in the basename itself.
    # def dir_constrained_base_names(app_name)
    #   constrained_base_names(app_name) +
    #     [
    #       "config",
    #       "config.ini",
    #     ]
    # end

    # # Return a list of possible INI configuration file basenames as might be
    # # placed in the user's home directory as a hidden file, but which need to
    # # contain a component of the app_name to distinguish it.
    # def dotted_base_names(app_name)
    #   [
    #     ".#{app_name}",
    #     ".#{app_name}rc",
    #     ".#{app_name}.ini",
    #     ".#{app_name}.cfg",
    #     ".#{app_name}.config"
    #   ]
    # end
  end
end
