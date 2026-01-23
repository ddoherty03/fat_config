# frozen_string_literal: true

module FatConfig
  class INIStyle < Style
    def load_string(str)
      # Since INIFile does not have a method for parsing strings, we have to
      # create a file with the string as content.
      tmp_path = Tempfile.create
      File.write(tmp_path, str)
      load_file(tmp_path)
    rescue IniFile::Error => ex
      raise FatConfig::ParseError, ex.to_s
    end

    def load_file(file_name)
      ini = IniFile.load(file_name)
      config = {}
      ini.each_section do |sec|
        case ini[sec]
        when Hash
          config[sec.to_sym] = ini[sec].methodize
        else
          config[sec.to_sym] = ini[sec]
        end
      end
      config
    rescue IniFile::Error => ex
      raise FatConfig::ParseError, ex.to_s
    end

    def possible_extensions
      super + ['ini']
    end
  end
end
