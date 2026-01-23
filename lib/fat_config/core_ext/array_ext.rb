# frozen_string_literal: true

class Array
  # Transform String hash keys to symbols suitable for calling as methods,
  # i.e., translate any hyphens to underscores.  This is the form we want to
  # keep config hashes in Labrat.  Leave non-String keys alone, so, e.g., an
  # Integer can be a key below the top-level
  def methodize
    new_arr = []
    each do |v|
      new_arr <<
          case v
          when Hash, Array
            v.methodize
          when Symbol, String
            # In case the key is a Symbol like :"a key-for-me", convert it back to
            # a String, then let #as_sym convert it to a proper Symbol that can be
            # used as a method call.
            v.as_sym
          else
            v
          end
    end
    new_arr
  end
end
