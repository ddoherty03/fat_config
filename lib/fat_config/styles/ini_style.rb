module FatConfig
  class INIStyle < Style
    def load_string(str)
      # Since INIFile does not have a method for parsing strings, we have to
      # create a file with the string as content.
      tmp_path = File.join("/tmp", "fat_config/ini#{$PID}")
      File.write(tmp_path, str)
      load_file(tmp_path)
    rescue IniFile::Error => ex
      raise FatConfig::ParseError, ex.to_s
    end

    def load_file(file_name)
      IniFile.load(file_name).to_h.methodize
    rescue IniFile::Error => ex
      raise FatConfig::ParseError, ex.to_s
    end

    def possible_extensions
      super + ['ini']
    end
  end
end
