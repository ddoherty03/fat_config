module FatConfig
  class JSONMerger
    def merge_files(files = [], verbose: false, permitted_classes: [])
      hash = {}
      files.each do |f|
        next unless File.readable?(f)

        json_hash = JSON.parse(File.read(f), symbolize_name: true)
        next unless json_hash

        if json_hash.is_a?(Hash)
          json_hash = json_hash.methodize
        else
          raise "Error loading file #{f}:\n#{File.read(f)[0..500]}"
        end
        json_hash.report("Merging config from file '#{f}") if verbose
        hash.deep_merge!(json_hash)
      end
      hash
    end

    # Return a list of possible YAML configuration file basenames where the
    # directory path already DOES NOT include the app_name so that the
    # basename itself must be distingashable as belonging to the app.
    def constrained_base_names(app_name)
      [
        app_name.to_s,
        "#{app_name}.json",
        "#{app_name}.cfg",
        "#{app_name}.config"
      ]
    end

    # Return a list of possible YAML configuration file basenames where the
    # directory path already includes the app_name so that it need not be
    # included in the basename itself.
    def dir_constrained_base_names(app_name)
      constrained_base_names(app_name) +
        [
          "config",
          "config.json",
        ]
    end

    # Return a list of possible YAML configuration file basenames as might be
    # placed in the user's home directory as a hidden file, but which need to
    # contain a component of the app_name to distinguish it.
    def dotted_base_names(app_name)
      [
        ".#{app_name}",
        ".#{app_name}rc",
        ".#{app_name}.json",
        ".#{app_name}.cfg",
        ".#{app_name}.config"
      ]
    end
  end
end
