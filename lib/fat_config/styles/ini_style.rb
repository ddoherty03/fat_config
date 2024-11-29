module FatConfig
  class INIStyle < Style
    def load_file(file_name)
      IniFile.load(file_name).to_h
    end

    def possible_extensions
      super + ['ini']
    end
  end
end
