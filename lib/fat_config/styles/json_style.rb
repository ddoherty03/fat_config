# frozen_string_literal: true

module FatConfig
  class JSONStyle < Style
    def load_string(str, file: 'string')
      JSON.parse(str).methodize
    rescue JSON::ParserError => ex
      line, column = extract_line_column(ex.message)
      snippet =
        if line
          ParseError.snippet_from_string(str, line: line, column: column)
        end
      raise(
        ParseError.new(
          file: file,
          format: :json,
          problem: ex.message,
          line: line,
          column: column,
          context: nil,
          snippet: snippet,
        ),
        cause: ex,
      )
    end

    def load_file(file_name)
      str = File.read(file_name, encoding: "UTF-8")
      load_string(str, file: file_name)
    end

    def possible_extensions
      super + ['json']
    end

    private

    # Best-effort: Ruby JSON error messages commonly include
    # "... at line 3, column 12"
    def extract_line_column(message)
      line = nil
      column = nil

      if message
        m = message.match(/line\s+(\d+)\s+.*column\s+(\d+)/i)
        if m
          line = m[1].to_i
          column = m[2].to_i
        else
          m2 = message.match(/line\s+(\d+)/i)
          if m2
            line = m2[1].to_i
          end
        end
      end
      [line, column]
    end
  end
end
