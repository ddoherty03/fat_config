module FatConfig
  # This class acts as a super class for specific styles of config files.  The
  # subclass must provide a load_file method that takes a file name, reads it
  # according to the rules of the Config style, and returns a Hash of the
  # config values.  The extent to which values are de-serialized from string
  # is up to the subclass.
  class Style
    # Read the file with the given name and return a Hash represented by the
    # config file.
    def load_file(file_name)
      raise NotImplementedError, "Style#load_file must be defined in a subclass of Style"
    end

    # The possible file extensions for files of this Style.  Here, we give the
    # generic config extensions, but the subclass should supplement it.
    def possible_extensions
      ['cfg', 'config']
    end

    # Read all the fiven system and user-level config files in order from
    # lower priority to higher priority, merging each along the way to build
    # the final Hash.  If requested, report the details to $stderr.
    def merge_files(sys_files = [], usr_files = [], verbose: false)
      hash = {}
      files = (sys_files + usr_files).compact
      files.each do |f|
        next unless File.readable?(f)

        file_hash = load_file(f)
        next unless file_hash

        if file_hash.is_a?(Hash)
          file_hash = file_hash.methodize
        else
          raise "Error loading file #{f}:\n#{File.read(f)[0..500]}"
        end
        if verbose
          warn "Merging system config from file '#{f}':" if sys_files.include?(f)
          warn "Merging user config from file '#{f}':" if usr_files.include?(f)
          hash.report_merge(file_hash)
        end
        hash.deep_merge!(file_hash)
      end
      hash
    end

    # Return a list of possible configuration file basenames where the
    # directory path DOES NOT already include the app_name so that the
    # basename itself must be distingashable as belonging to the app.
    def constrained_base_names(base)
      [base] + possible_extensions.map { |ext| "#{base}.#{ext}" }
    end

    # Return a list of possible configuration file basenames where the
    # directory path DOES already includes the app_name so that it need not be
    # included in the basename itself.
    def dir_constrained_base_names(base)
      constrained_base_names(base) + ['config'] + possible_extensions.map { |ext| "config.#{ext}" }
    end

    # Return a list of possible configuration file basenames as might be
    # placed in the user's home directory as a hidden file, but which need to
    # contain a component of the app_name to distinguish it.
    def dotted_base_names(base)
      [".#{base}", ".#{base}rc"] + possible_extensions.map { |ext| ".#{base}.#{ext}" }
    end
  end
end

require_relative 'styles/yaml_style'
require_relative 'styles/toml_style'
require_relative 'styles/ini_style'
require_relative 'styles/json_style'
