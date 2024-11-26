^module FatConfig
  class YAMLMerger
    def merge_files(files = [], verbose: false, permitted_classes: [])
      hash = {}
      files.each do |f|
        next unless File.readable?(f)

        yml_hash =
          if permitted_classes
            Psych.safe_load(File.read(f), permitted_classes:)
          else
            Psych.safe_load(File.read(f))
          end
        next unless yml_hash

        if yml_hash.is_a?(Hash)
          yml_hash = yml_hash.methodize
        else
          raise "Error loading file #{f}:\n#{File.read(f)[0..500]}"
        end
        yml_hash.report("Merging config from file '#{f}") if verbose
        hash.deep_merge!(yml_hash)
      end
      hash
    end
  end
end
