# frozen_string_literal: true

module FatConfig
  # This class is responsible for finding a config files, reading them, and
  # returning a Hash to reflect the configuration.  We use YAML as the
  # configuration format and look for the config file in the standard places.
  class Reader
    # - ~app_name~ :: used to form environment variables for config locations.
    # - ~config_lang~ :: either :yaml or :toml or :json or :ini
    # - ~root_prefix~ :: an alternate root of the assumed file system, by
    #   default ''.  This facilitated testing.
    # - ~xdg~ :: whether follow XDG desktop conventions, by default true; if
    #   false, use "classic" UNIX config practices with /etc/ and ~/.baserc.
    # - ~permitted_classes~ :: Psych parameter for classes that can be
    #   deserialized into Ruby class instances,

    attr_reader :app_name, :config_style, :root_prefix, :xdg, :file_merger, :permitted_classes

    VALID_CONFIG_STYLES = [:yaml, :toml, :json, :ini]

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
    def initialize(app_name, config_style: :yaml, root_prefix: '', xdg: true, permitted_classes: nil)
      @app_name = app_name.strip.downcase
      raise ArgumentError, "reader app name may not be blank" if @app_name.blank?
      msg = "reader app name may only contain letters, numbers, and underscores"
      raise ArgumentError, msg unless @app_name.match(/\A[a-z][a-z0-9_]*\z/)

      @root_prefix = root_prefix
      @xdg = xdg
      @permitted_classes = permitted_classes || []

      @config_style = config_style.downcase.to_sym
      @file_merger =
        case @config_style
        when :yaml
          YAMLMerger.new
        when :toml
          TOMLMerger.new
        else
          msg = "config style must be one of #{VALID_CONFIG_STYLES.join(', ')}"
          raise ArgumentError, msg unless VALID_CONFIG_STYLES.include?(@config_style)
        end
    end

    # Return a Hash of the YAML-ized config files for app_name directories.
    # Config file may be located in either the xdg locations (containing any
    # variant of base: base, base.yml, or base.yaml) or in the classic
    # locations (/etc/app_namerc, /etc/app_name, ~/.app_namerc~, or
    # ~/.app_name/base[.ya?ml]). Return a hash that reflects the merging of
    # those files according to the following priorities, from highest to
    # lowest:
    #
    # 1. A config file pointed to by the environment variable APPNAME_CONFIG
    # 2. User classic config files
    # 3. User xdg config files for app_name,
    # 4. A config file pointed to by the environment variable APPNAME_SYS_CONFIG
    # 5. System classic config files,
    # 6. System xdg config files for for app_name,
    #
    # If an environment variable is found, the search for xdg and classic
    # config files is skipped. Any dir_prefix is pre-pended to search
    # locations environment, xdg and classic config paths so you can run this
    # on a temporary directory set up for testing.
    #
    def read(verbose: false)
      paths = config_paths
      sys_configs = paths[:system]
      usr_configs = paths[:user]
      file_merger.merge_files((sys_configs + usr_configs).compact, verbose: verbose)
    end

    def config_paths
      sys_configs = []
      sys_env_name = "#{app_name.upcase}_SYS_CONFIG"
      if ENV[sys_env_name]
        sys_fname = File.join(root_prefix, File.expand_path(ENV[sys_env_name]))
        sys_configs << sys_fname if File.readable?(sys_fname)
      else
        sys_configs +=
          if xdg
            find_xdg_sys_config_files
          else
            find_classic_sys_config_files
          end
      end

      usr_configs = []
      usr_env_name = "#{app_name.upcase}_CONFIG"
      if ENV[usr_env_name]
        usr_fname = File.join(root_prefix, File.expand_path(ENV[usr_env_name]))
        usr_configs << usr_fname if File.readable?(usr_fname)
      else
        usr_configs <<
          if xdg
            find_xdg_user_config_file
          else
            find_classic_user_config_file
          end
      end
      { system: sys_configs.compact, user: usr_configs.compact }
    end

   ########################################################################
    # XDG config files
    ########################################################################

    # From the XDG standard:
    # Your application should store and load data and configuration files to/from
    # the directories pointed by the following environment variables:
    #
    # $XDG_CONFIG_HOME (default: "$HOME/.config"): user-specific configuration files.
    # $XDG_CONFIG_DIRS (default: "/etc/xdg"): precedence-ordered set of system configuration directories.

    # Return the absolute path names of all XDG system config files for
    # app_name with the basename variants of base. Return the lowest priority
    # files first, highest last. Prefix the search locations with dir_prefix
    # if given.
    def find_xdg_sys_config_files
      configs = []
      xdg_search_dirs = ENV['XDG_CONFIG_DIRS']&.split(':')&.reverse || ['/etc/xdg']
      xdg_search_dirs.each do |dir|
        dir = File.expand_path(File.join(dir, app_name))
        dir = File.join(root_prefix, dir) unless root_prefix.nil? || root_prefix.strip.empty?
        base_candidates = [app_name.to_s, "#{app_name}.yml", "#{app_name}.yaml", "config.yml", "config.yaml",
                           "#{app_name}.cfg", "#{app_name}.config"]
        config_fname = base_candidates.find { |b| File.readable?(File.join(dir, b)) }
        configs << File.join(dir, config_fname) if config_fname
      end
      configs
    end

    # Return the absolute path name of any XDG user config files for app_name
    # with the basename variants of base. The XDG_CONFIG_HOME environment
    # variable for the user configs is intended to be the name of a single xdg
    # config directory, not a list of colon-separated directories as for the
    # system config. Return the name of a config file for this app in
    # XDG_CONFIG_HOME (or ~/.config by default).  Prefix the search location
    # with dir_prefix if given.
    def find_xdg_user_config_file
      base ||= (base&.strip || app_name)
      xdg_search_dir = ENV['XDG_CONFIG_HOME'] || ['~/.config']
      dir = File.expand_path(File.join(xdg_search_dir, app_name))
      dir = File.join(root_prefix, dir) unless root_prefix.strip.empty?
      return unless Dir.exist?(dir)

      base_candidates = [app_name.to_s, "#{app_name}.yml", "#{app_name}.yaml", "config.yml", "config.yaml",
                         "#{app_name}.cfg", "#{app_name}.config"]
      config_fname = base_candidates.find { |b| File.readable?(File.join(dir, b)) }
      if config_fname
        File.join(dir, config_fname)
      end
    end

    ########################################################################
    # Classic config files
    ########################################################################

    # Return the absolute path names of all "classic" system config files for
    # app_name with the basename variants of base. Return the lowest priority
    # files first, highest last.  Prefix the search locations with dir_prefix
    # if given.
    def find_classic_sys_config_files
      configs = []
      env_config = ENV["#{app_name.upcase}_SYS_CONFIG"]
      if env_config && File.readable?((config = File.join(root_prefix, File.expand_path(env_config))))
        configs = [config]
      elsif File.readable?(config = File.join(root_prefix, "/etc/#{app_name}"))
        configs = [config]
      elsif File.readable?(config = File.join(root_prefix, "/etc/#{app_name}rc"))
        configs = [config]
      else
        dir = File.join(root_prefix, "/etc/#{app_name}")
        if Dir.exist?(dir)
          base_candidates = ["#{app_name}" "#{app_name}.yml", "#{app_name}.yaml",
                             "#{app_name}.cfg", "#{app_name}.config"]
          config = base_candidates.find { |b| File.readable?(File.join(dir, b)) }
          configs = [File.join(dir, config)] if config
        end
      end
      configs
    end

    # Return the absolute path names of all "classic" system config files for
    # app_name with the basename variants of base. Return the lowest priority
    # files first, highest last.  Prefix the search locations with dir_prefix if
    # given.
    def find_classic_user_config_file
      config_fname = nil
      env_config = ENV["#{app_name.upcase}_CONFIG"]
      if env_config && File.readable?((config = File.join(root_prefix, File.expand_path(env_config))))
        config_fname = config
      elsif Dir.exist?(config_dir = File.join(root_prefix, File.expand_path("~/.#{app_name}")))
        base_candidates = ["config.yml", "config.yaml", "config"]
        base_fname = base_candidates.find { |b| File.readable?(File.join(config_dir, b)) }
        config_fname = File.join(config_dir, base_fname)
      elsif Dir.exist?(config_dir = File.join(root_prefix, File.expand_path('~/')))
        base_candidates = [".#{app_name}", ".#{app_name}rc", ".#{app_name}.yml", ".#{app_name}.yaml",
                           ".#{app_name}.cfg", ".#{app_name}.config"]
        base_fname = base_candidates.find { |b| File.readable?(File.join(config_dir, b)) }
        config_fname = File.join(config_dir, base_fname)
      end
      config_fname
    end
  end
end
