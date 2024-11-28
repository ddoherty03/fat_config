module FatConfig
  RSpec.describe Hash do
    it "reports changes in a merge" do
      old = {a: 1, b: 2, c: 3, d: 4, e: 5}
      new = {d: 4, e: 8, f: 9, g: 11}
      old.report_merge(new)
    end

    it "parses a string into a Hash" do
      hsh = Hash.parse_opts("--hello-thing=world --doit --the_num=3.14159 --the-date=2024-11-27 --no-bueno")
      expect(hsh.keys).to include(:hello_thing)
      expect(hsh.keys).to include(:doit)
      expect(hsh.keys).to include(:the_num)
      expect(hsh.keys).to include(:the_date)
      expect(hsh.keys).to include(:bueno)
      expect(hsh[:hello_thing]).to eq("world")
      expect(hsh[:doit]).to be(true)
      expect(hsh[:the_num]).to eq("3.14159")
      expect(hsh[:the_date]).to eq("2024-11-27")
      expect(hsh[:bueno]).to be(false)
    end

    it "ignores non-option text" do
      hsh = Hash.parse_opts("four score --and 46546 years ago")
      expect(hsh.keys.size).to eq(1)
      expect(hsh[:and]).to be true
    end
  end
end
