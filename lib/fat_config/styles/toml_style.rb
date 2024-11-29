module FatConfig
  class TOMLStyle < Style
    def load_file(file_name)
      Tomlib.load(File.read(file_name))
    end

    def possible_extensions
      super + ['toml']
    end
  end
end
