# frozen_string_literal: true

module FatConfig
  class TOMLStyle < Style
    def load_string(str)
      Tomlib.load(str)&.methodize
    rescue Tomlib::ParseError => ex
      raise FatConfig::ParseError, ex.to_s
    end

    def load_file(file_name)
      load_string(File.read(file_name))
    end

    def possible_extensions
      super + ['toml']
    end
  end
end
