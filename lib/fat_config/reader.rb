# frozen_string_literal: true

module FatConfig
  # This class is responsible for finding a config files, reading them, and
  # returning a Hash to reflect the configuration.  We use YAML as the
  # configuration format and look for the config file in the standard places.
  class Reader
    VALID_CONFIG_STYLES = [:yaml, :toml, :json, :ini]

    # - ~app_name~ :: used to form environment variables for config locations.
    # - ~style~ :: either :yaml or :toml or :json or :ini
    # - ~xdg~ :: whether follow XDG desktop conventions, by default true; if
    #   false, use "classic" UNIX config practices with /etc/ and ~/.baserc.
    # - ~root_prefix~ :: an alternate root of the assumed file system, by
    #   default ''.  This facilitated testing.
    attr_reader :app_name, :style, :root_prefix, :xdg

    def initialize(app_name, style: :yaml, xdg: true, root_prefix: '')
      @app_name = app_name.strip.downcase
      raise ArgumentError, "reader app name may not be blank" if @app_name.blank?

      msg = "reader app name may only contain letters, numbers, and underscores"
      raise ArgumentError, msg unless app_name.match?(/\A[a-z][a-z0-9_]*\z/)

      @root_prefix = root_prefix
      @xdg = xdg

      style = style.downcase.to_sym
      @style =
        case style
        when :yaml
          YAMLStyle.new
        when :toml
          TOMLStyle.new
        when :ini
          INIStyle.new
        when :json
          JSONStyle.new
        else
          msg = "config style must be one of #{VALID_CONFIG_STYLES.join(', ')}"
          raise ArgumentError, msg
        end
    end

    # Return a Hash of the config files for app_name directories.
    # Config file may be located in either the xdg locations (containing any
    # variant of base: base, base.yml, or base.yaml) or in the classic
    # locations (/etc/app_namerc, /etc/app_name, ~/.app_namerc~, or
    # ~/.app_name/base.ext). Return a hash that reflects the merging of
    # those files according to the following priorities, from highest to
    # lowest:
    #
    # 1. Options passed in the String or Hash parameter, command_line
    # 2. Options passed by an environment variable APPNAME_OPTIONS
    # 3. If the xdg parameter is true:
    #    a. Either:
    #       A. The file pointed to by the environment variable APPNAME_CONFIG or
    #       B. User xdg config files for app_name,
    #    b. Then, either:
    #       A. The file pointed to by the environment variable APPNAME_SYS_CONFIG or
    #       B. System xdg config files for for app_name,
    # 4. If the xdg parameter is false:
    #    a. Either:
    #       A. The file pointed to by the environment variable APPNAME_CONFIG or
    #       B. User classic config files
    #    b. Then, either:
    #       A. The file pointed to by the environment variable APPNAME_SYS_CONFIG or
    #       B. System classic config files,
    #
    # Any root_prefix is pre-pended to file-based search locations environment, xdg and
    # classic config paths so you can run this on a temporary directory set up for
    # testing.
    #
    def read(alt_base = app_name, command_line: {}, verbose: false)
      paths = config_paths(alt_base)
      sys_configs = paths[:system]
      usr_configs = paths[:user]
      if verbose
        if sys_configs.empty?
          warn "No system config files found."
        else
          warn "System config files found: #{sys_configs.join('; ')}"
        end
        if usr_configs.empty?
          warn "No user config files found."
        else
          warn "User config files found: #{usr_configs.join('; ')}"
        end
      end
      result = style.merge_files(sys_configs, usr_configs, verbose: verbose)
      result = merge_environment(result, verbose: verbose)
      merge_command_line(result, command_line, verbose: verbose)
    end

    def merge_environment(start_hash, verbose: false)
      return start_hash if ENV[env_name].blank?

      env_hash = Hash.parse_opts(ENV[env_name])
      if verbose
        warn "Merging environment from #{env_name}:"
        start_hash.report_merge(env_hash)
      end
      start_hash.merge(env_hash)
    end

    def merge_command_line(start_hash, command_line, verbose: false)
      return start_hash unless command_line

      return start_hash if command_line.empty?

      cl_hash =
        case command_line
        when String
          Hash.parse_opts(command_line)
        when Hash
          command_line
        else
          raise ArgumentError, "command_line must be a String or Hash"
        end
      if verbose
        warn "Merging command-line:"
        start_hash.report_merge(cl_hash)
      end
      start_hash.merge(cl_hash)
    end

    def env_name
      "#{app_name.upcase}_OPTIONS"
    end

    def config_paths(base = app_name)
      sys_configs = []
      sys_env_name = "#{app_name.upcase}_SYS_CONFIG"
      if ENV[sys_env_name]
        sys_fname = File.join(root_prefix, File.expand_path(ENV[sys_env_name]))
        sys_configs << sys_fname if File.readable?(sys_fname)
      else
        sys_configs +=
          if xdg
            find_xdg_sys_config_files(base)
          else
            find_classic_sys_config_files(base)
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
            find_xdg_user_config_file(base)
          else
            find_classic_user_config_file(base)
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
    def find_xdg_sys_config_files(base = app_name)
      configs = []
      xdg_search_dirs = ENV['XDG_CONFIG_DIRS']&.split(':')&.reverse || ['/etc/xdg']
      xdg_search_dirs.each do |dir|
        dir = File.expand_path(File.join(dir, app_name))
        dir = File.join(root_prefix, dir) unless root_prefix.nil? || root_prefix.strip.empty?
        base_candidates = style.dir_constrained_base_names(base)
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
    def find_xdg_user_config_file(base = app_name)
      xdg_search_dir = ENV['XDG_CONFIG_HOME'] || ['~/.config']
      dir = File.expand_path(File.join(xdg_search_dir, app_name))
      dir = File.join(root_prefix, dir) unless root_prefix.strip.empty?
      return unless Dir.exist?(dir)

      base_candidates = style.dir_constrained_base_names(base)
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
    def find_classic_sys_config_files(base = app_name)
      configs = []
      env_config = ENV["#{app_name.upcase}_SYS_CONFIG"]
      if env_config && File.readable?((config = File.join(root_prefix, File.expand_path(env_config))))
        configs = [config]
      elsif File.readable?(config = File.join(root_prefix, "/etc/#{base}"))
        configs = [config]
      elsif File.readable?(config = File.join(root_prefix, "/etc/#{base}rc"))
        configs = [config]
      else
        dir = File.join(root_prefix, "/etc/#{app_name}")
        if Dir.exist?(dir)
          base_candidates = style.classic_base_names(base)
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
    def find_classic_user_config_file(base = app_name)
      env_config = ENV["#{app_name.upcase}_CONFIG"]
      if env_config && File.readable?((config = File.join(root_prefix, File.expand_path(env_config))))
        config
      else
        config_dir = File.join(root_prefix, File.expand_path("~/"))
        base_candidates = style.dotted_base_names(base)
        base_fname = base_candidates.find do |b|
          File.file?(File.join(config_dir, b)) && File.readable?(File.join(config_dir, b))
        end
        if base_fname
          File.join(config_dir, base_fname)
        elsif Dir.exist?(config_dir = File.join(root_prefix, File.expand_path("~/.#{app_name}")))
          base_candidates = style.dir_constrained_base_names(base)
          base_fname = base_candidates.find { |b| File.readable?(File.join(config_dir, b)) }
          File.join(config_dir, base_fname) if base_fname
        end
      end
    end
  end
end
