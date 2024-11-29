module FatConfig
  class JSONStyle < Style
    def load_file(file_name)
      JSON.parse(File.read(file_name), symbolize_name: true)
    end

    def possible_extensions
      super + ['json']
    end
  end
end
