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
      new_hash[k.to_s.tr('-', '_').to_sym] = new_val
    end
    new_hash
  end

  # Print to $stderr the changes wrought by merging new_hash into this one.
  def report_merge(new_hash, indent: 2)
    new_keys = new_hash.keys
    old_keys = keys
    unchanged_keys = old_keys - new_keys
    added_keys = new_keys - old_keys
    changed_keys = old_keys & new_keys
    space = ' ' * indent
    (keys + added_keys).sort.each do |k|
      if (self[k].nil? || self[k].is_a?(Hash)) && new_hash[k].is_a?(Hash)
        # Recurse if the value is a Hash
        warn "#{space}Config key: #{k}:"
        (self[k] || {}).report_merge(new_hash[k], indent: indent + 2)
        next
      end
      if unchanged_keys.include?(k)
        warn "#{space}Unchanged: #{k}: #{self[k]}"
      elsif added_keys.include?(k)
        warn "#{space}Added:     #{k}: #{new_hash[k]}"
      elsif changed_keys.include?(k)
        if self[k] != new_hash[k]
          warn "#{space}Changed:   #{k}: #{self[k]} -> #{new_hash[k]}"
        else
          warn "#{space}Unchanged: #{k}: #{self[k]} -> #{new_hash[k]}"
        end
      else
        raise ArgumentError, "FatConfig report_merge has unmatched key: #{k}"
      end
    end
    self
  end

  # Parse a string of the form "--key-one=val1 --flag --key2=val2" into a
  # Hash, where the value of the --flag is set to true unless its name starts
  # with "no" or "no_" or "!", then set it to false and its name is stripped
  # of the leading negator.  It also converts all the keys to symbols suitable
  # as Ruby id's using Hash#methodize.  Ignore anything that doesn't look like
  # an option or flag.
  def self.parse_opts(str)
    hsh = Hash[str.scan(/--?([^=\s]+)(?:=(\S+))?/)]
    result = {}
    hsh.each_pair do |k, v|
      if v.nil?
        if k =~ /\A((no[-_]?)|!)(?<name>.*)\z/
          new_key = Regexp.last_match["name"]
          result[new_key] = false
        else
          result[k] = true
        end
      else
        result[k] = v
      end
    end
    result.methodize
  end
end
