module FatConfig
  class TOMLMerger
    def merge_files(files = [], verbose: false, permitted_classes: [])
      hash = {}
      files.each do |f|
        next unless File.readable?(f)

        toml_hash = Tomlib.load(File.read(f))
        next unless toml_hash

        if toml_hash.is_a?(Hash)
          toml_hash = toml_hash.methodize
        else
          raise "Error loading file #{f}:\n#{File.read(f)[0..500]}"
        end
        toml_hash.report("Merging config from file '#{f}") if verbose
        hash.deep_merge!(toml_hash)
      end
      hash
    end
  end
end
