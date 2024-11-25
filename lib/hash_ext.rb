# frozen_string_literal: true
class Hash
  # Transform hash keys to symbols suitable for calling as methods, i.e.,
  # translate any hyphens to underscores.  This is the form we want to keep
  # config hashes in Labrat.
  def methodize
    transform_keys { |k| k.to_s.gsub('-', '_').to_sym }
  end
end
