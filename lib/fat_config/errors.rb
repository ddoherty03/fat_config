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
      line = line&.to_i || 1
      column = column&.to_i || 0
      if str && line && line.to_i > 0
        lines = str.lines.map(&:chomp)
        (lines[0..line - 1] +
          [(' ' * column) + '^'] +
          lines[line..]).join("\n")
      end
    end

    def self.snippet_from_file(file_name, line:, column:)
      text = nil
      begin
        text = File.read(file_name, encoding: "UTF-8")
      rescue StandardError
        text = nil
      end
      if text
        snippet_from_string(text, line: line, column: column)
      end
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
      msg = +"#{format.to_s.upcase} parse error in:\n  #{file}\n  #{loc}:\n\nERROR:#{problem}"
      if snippet && !snippet.empty?
        msg << "\n\n===========================\n"
        msg << snippet
        msg << "\n===========================\n\n"
      end
      if context && !context.empty?
        msg << "\n\n==========================="
        msg << context
        msg << "===========================\n\n"
      end
      msg
    end
  end
end
