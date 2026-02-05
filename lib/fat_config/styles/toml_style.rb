# frozen_string_literal: true

module FatConfig
  class TOMLStyle < Style
    def load_string(str, file: "string")
      data = Tomlib.load(str)
      data ||= {}
      data.methodize
    rescue Tomlib::ParseError => ex
      line, column, problem, context = extract_error(ex)
      snippet =
        if line
          ParseError.snippet_from_string(str, line: line, column: column)
        end
      raise(
        ParseError.new(
          file: file,
          format: :toml,
          problem: problem || ex.message,
          line: line,
          column: column,
          context: context,
          snippet: snippet,
        ),
        cause: ex,
      )
    end

    def load_file(file_name)
      str = File.read(file_name, encoding: "UTF-8")
      data = load_string(str, file: file_name)
      data
    end

    def possible_extensions
      super + ['toml']
    end

    private

    def extract_error(ex)
      line = nil
      column = nil
      context = nil

      if ex.respond_to?(:line)
        v = ex.line
        line = v.to_i if v
      elsif ex.respond_to?(:lineno)
        v = ex.lineno
        line = v.to_i if v
      end

      if ex.respond_to?(:column)
        v = ex.column
        column = v.to_i if v
      elsif ex.respond_to?(:colno)
        v = ex.colno
        column = v.to_i if v
      end

      problem =
        if ex.respond_to?(:problem)
          ex.problem
        else
          ex.message
        end

      context = ex.context if ex.respond_to?(:context)

      if (line.nil? || column.nil?) && ex.message
        m = ex.message.match(/line\s+(\d+)\s*,?\s*(?:col(?:umn)?|column)\s+(\d+)/i)
        if m
          line ||= m[1].to_i
          column ||= m[2].to_i
        else
          m2 = ex.message.match(/line\s+(\d+)/i)
          line ||= m2[1].to_i if m2
        end
      end
      [line, column, problem, context]
    end
  end
end
