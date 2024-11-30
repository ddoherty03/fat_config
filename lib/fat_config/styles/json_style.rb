module FatConfig
  class JSONStyle < Style
    def load_string(str)
      JSON.parse(str, symbolize_name: true).methodize
    rescue JSON::ParserError => ex
      raise FatConfig::ParseError, ex.to_s
    end

    def load_file(file_name)
      load_string(File.read(file_name))
    end

    def possible_extensions
      super + ['json']
    end
  end
end
