module FatConfig
  RSpec.describe Hash do
    it "reports changes in a merge" do
      old = {a: 1, b: 2, c: 3, d: 4, e: 5}
      new = {d: 4, e: 8, f: 9, g: 11}
      old.report_merge(new)
    end
  end
end
