require "spec"
require "yaml"

describe "YAML" do
  describe "parser" do
    assert { YAML.parse("foo").should eq("foo") }
    assert { YAML.parse("- foo\n- bar").should eq(["foo", "bar"]) }
    assert { YAML.parse_all("---\nfoo\n---\nbar\n").should eq(["foo", "bar"]) }
    assert { YAML.parse("foo: bar").should eq({"foo" => "bar"}) }
    assert { YAML.parse("--- []\n").should eq([] of YAML::Type) }
    assert { YAML.parse("---\n...").should eq("") }

    it "parses recursive sequence" do
      doc = YAML.parse("--- &foo\n- *foo\n")
      doc[0].raw.should be(doc.raw)
    end

    it "parses recursive mapping" do
      doc = YAML.parse(%(--- &1
        friends:
        - *1
        ))
      doc["friends"][0].raw.should be(doc.raw)
    end

    it "parses alias to scalar" do
      doc = YAML.parse("---\n- &x foo\n- *x\n")
      doc.should eq(["foo", "foo"])
      doc[0].raw.should be(doc[1].raw)
    end

    describe "merging with << key" do
      it "merges other mapping" do
        doc = YAML.parse(%(---
          foo: bar
          <<:
            baz: foobar
          ))
        doc["baz"]?.should eq("foobar")
      end

      it "raises if merging with missing alias" do
        expect_raises do
          YAML.parse(%(---
            foo:
              <<: *bar
          ))
        end
      end

      it "doesn't merge explicit string key <<" do
        doc = YAML.parse(%(---
          foo: &foo
            hello: world
          bar:
            !!str '<<': *foo
        ))
        doc.should eq({"foo": {"hello": "world"}, "bar": {"<<": {"hello": "world"}}})
      end

      it "doesn't merge empty mapping" do
        doc = YAML.parse(%(---
          foo: &foo
          bar:
            <<: *foo
        ))
        doc["bar"].should eq({"<<": ""})
      end

      it "doesn't merge arrays" do
        doc = YAML.parse(%(---
          foo: &foo
            - 1
          bar:
            <<: *foo
        ))
        doc["bar"].should eq({"<<": ["1"]})
      end
    end
  end

  describe "dump" do
    it "returns YAML as a string" do
      YAML.dump(%w(1 2 3)).should eq("--- \n- 1\n- 2\n- 3")
    end

    it "writes YAML to a stream" do
      string = String.build do |str|
        YAML.dump(%w(1 2 3), str)
      end
      string.should eq("--- \n- 1\n- 2\n- 3")
    end
  end
end
