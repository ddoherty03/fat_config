# frozen_string_literal: true

module FatConfig
  class INIStyle < Style
    def load_string(str)
      # Since INIFile does not have a method for parsing strings, we have to
      # create a file with the string as content.
      tmp = Tempfile.create("fat_config_ini")
      tmp.write(str)
      tmp.flush
      load_file(tmp.path)
    rescue IniFile::Error => ex
      snippet = snippet_from_inifile_error(ex)
      raise(
        ParseError.new(
          file: "string",
          format: :ini,
          problem: ex.message,
          line: nil,
          column: nil,
          context: nil,
          snippet: snippet,
        ),
        cause: ex,
      )
    end

    def load_file(file_name)
      ini = IniFile.load(file_name)
      config = {}
      ini.each_section do |sec|
        config[sec.to_sym] =
          case ini[sec]
          when Hash
            ini[sec].methodize
          else
            ini[sec]
          end
      end
      config
    rescue IniFile::Error => ex
      snippet = snippet_from_inifile_error(ex)
      raise(
        ParseError.new(
          file: file_name,
          format: :ini,
          problem: ex.message,
          line: nil,
          column: nil,
          context: nil,
          snippet: snippet,
        ),
        cause: ex,
      )
    end

    def possible_extensions
      super + ['ini']
    end

    private

    # IniFile::Error messages commonly end with the offending line via inspect,
    # e.g. 'expected "=": "bad line"'. We can at least surface that line.
    def snippet_from_inifile_error(ex)
      line_text = nil
      if ex&.message
        m = ex.message.match(/:\s*(\".*\"|\'.*\')\s*\z/)
        if m
          begin
            line_text = eval(m[1])
          rescue StandardError
            line_text = m[1]
          end
        end
      end
      snippet = nil
      if line_text && !line_text.empty?
        snippet = +"#{line_text}\n^\n"
      end
      snippet
    end
  end
end
