# in fat_config/parse_error.rb (or wherever ParseError lives)
module FatConfig
  class ParseError < StandardError
    attr_reader :file, :format, :line, :column, :problem, :context, :snippet

    def initialize(file:, format:, problem:, line: nil, column: nil, context: nil, snippet: nil)
      @file = file
      @format = format
      @problem = problem
      @line = line
      @column = column
      @context = context
      @snippet = snippet
      super(build_message)
    end

    def self.snippet_from_string(str, line:, column:)
      snippet = nil

      if str && line && line.to_i > 0
        lines = str.lines
        idx = line.to_i - 1
        if idx >= 0 && idx < lines.length
          src = lines[idx].chomp
          caret =
            if column
              (" " * column.to_i) + "^"
            end
          snippet = [src, caret].compact.join("\n")
        end
      end

      snippet
    end

    def self.snippet_from_file(file_name, line:, column:)
      text = nil

      begin
        text = File.read(file_name, encoding: "UTF-8")
      rescue StandardError
        text = nil
      end

      snippet = nil
      if text
        snippet = snippet_from_string(text, line: line, column: column)
      end

      snippet
    end

    private

    def build_message
      loc =
        if line && column
          " at line #{line}, column #{column}"
        elsif line
          " at line #{line}"
        else
          ""
        end

      msg = +"#{format.to_s.upcase} parse error in #{file}#{loc}: #{problem}"

      if snippet && !snippet.empty?
        msg << "\n\n#{snippet}"
      end

      if context && !context.empty?
        msg << "\n\n#{context}"
      end

      msg
    end
  end
end
