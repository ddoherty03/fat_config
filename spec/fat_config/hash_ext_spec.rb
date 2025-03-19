module FatConfig
  RSpec.describe Hash do
    it 'mehtodized keys' do
      old = { 'first key': 1, second_key: 2, 'Third key': 3, 'fourth-key': 4, 'Fifth    Key': 5 }
      new = old.methodize
      expect(new.keys).to all match(/\A[a-z_][a-z0-9_]+/)
    end

    it "reports changes in a merge" do
      old = { a: 1, b: 2, c: 3, d: 4, e: 5 }
      new = { d: 4, e: 8, f: 9, g: 11 }
      result = capture { old.report_merge(new) }
      # Stderr should be:
      #
      # Unchanged: a: 1
      # Unchanged: b: 2
      # Unchanged: c: 3
      # Unchanged: d: 4 -> 4
      # Changed:   e: 5 -> 8
      # Added:     f: 9
      # Added:     g: 11
      warn result[:stderr]
      expect(result[:stderr]).to match(/Unchanged:\s+a:\s+1/)
      expect(result[:stderr]).to match(/Unchanged:\s+b:\s+2/)
      expect(result[:stderr]).to match(/Unchanged:\s+c:\s+3/)
      expect(result[:stderr]).to match(/Unchanged:\s+d:\s+4/)
      expect(result[:stderr]).to match(/Changed:\s+e:\s+5 -> 8/)
      expect(result[:stderr]).to match(/Added:\s+f:\s+9/)
      expect(result[:stderr]).to match(/Added:\s+g:\s+11/)
    end

    it "parses a string into a Hash" do
      hsh = Hash.parse_opts("--hello='hello, world' --gb=goodbye junk --doit --the-num=3.14159 --no-bueno --~junk")
      expect(hsh.keys).to include(:hello)
      expect(hsh.keys).to include(:gb)
      expect(hsh.keys).to include(:doit)
      expect(hsh.keys).to include(:the_num)
      expect(hsh.keys).to include(:bueno)
      expect(hsh.keys).to include(:junk)
      expect(hsh[:hello]).to eq("hello, world")
      expect(hsh[:gb]).to eq("goodbye")
      expect(hsh[:doit]).to be(true)
      expect(hsh[:the_num]).to eq("3.14159")
      expect(hsh[:bueno]).to be(false)
      expect(hsh[:junk]).to be(false)
    end

    it "ignores non-option text" do
      hsh = Hash.parse_opts("four score --and 46546 years ago")
      expect(hsh.keys.size).to eq(1)
      expect(hsh[:and]).to be true
    end
  end
end
