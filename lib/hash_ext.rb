# frozen_string_literal: true
class Hash
  # Transform hash keys to symbols suitable for calling as methods, i.e.,
  # translate any hyphens to underscores.  This is the form we want to keep
  # config hashes in Labrat.
  def methodize
    new_hash = {}
    each_pair do |k, v|
      new_val =
        if v.is_a?(Hash)
          v.methodize
        else
          v
        end
      new_hash[k.to_s.gsub('-', '_').to_sym] = new_val
    end
    new_hash
  end
end
