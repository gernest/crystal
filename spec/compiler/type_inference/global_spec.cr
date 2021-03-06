require "../../spec_helper"

describe "Global inference" do
  it "infers type of global assign" do
    node = parse "$foo = 1"
    result = infer_type node
    mod, node = result.program, result.node as Assign

    node.type.should eq(mod.int32)
    node.target.type.should eq(mod.int32)
    node.value.type.should eq(mod.int32)
  end

  it "infers type of global assign with union" do
    nodes = parse "$foo = 1; $foo = 'a'"
    result = infer_type nodes
    mod, node = result.program, result.node as Expressions

    (node[0] as Assign).target.type.should eq(mod.union_of(mod.int32, mod.char))
    (node[1] as Assign).target.type.should eq(mod.union_of(mod.int32, mod.char))
  end

  it "errors when reading undefined global variables" do
    assert_error %(
      $x
      ), "undefined global variable '$x'"
  end

  it "errors when writing undefined global variables" do
    assert_error %(
      def foo
        1
      end

      $x = foo
      ), "undefined global variable '$x'"
  end

  it "infers type from number literal" do
    assert_type(%(
      $x = 1
      $x
      )) { int32 }
  end

  it "infers type from char literal" do
    assert_type(%(
      $x = 'a'
      $x
      )) { char }
  end

  it "infers type from bool literal" do
    assert_type(%(
      $x = true
      $x
      )) { bool }
  end

  it "infers type from nil literal" do
    assert_type(%(
      $x = nil
      $x
      )) { |mod| mod.nil }
  end

  it "infers type from string literal" do
    assert_type(%(
      $x = "foo"
      $x
      )) { string }
  end

  it "infers type from string interpolation" do
    assert_type(%(
      require "prelude"

      $x = "foo\#{1}"
      $x
      )) { string }
  end

  it "infers type from symbol literal" do
    assert_type(%(
      $x = :foo
      $x
      )) { symbol }
  end

  it "infers type from array literal with of" do
    assert_type(%(
      $x = [] of Int32
      $x
      )) { array_of int32 }
  end

  it "infers type from array literal with of (metaclass)" do
    assert_type(%(
      $x = [] of Int32.class
      $x
      )) { array_of int32.metaclass }
  end

  it "infers type from array literal with of, inside another type" do
    assert_type(%(
      class Foo
        class Bar
        end

        $x = [] of Bar
      end

      $x
      )) { array_of types["Foo"].types["Bar"] }
  end

  it "infers type from array literal from its literals" do
    assert_type(%(
      require "prelude"

      $x = [1, 'a']
      $x
      )) { array_of union_of(int32, char) }
  end

  it "infers type from hash literal with of" do
    assert_type(%(
      require "prelude"

      $x = {} of Int32 => String
      $x
      )) { hash_of(int32, string) }
  end

  it "infers type from hash literal from elements" do
    assert_type(%(
      require "prelude"

      $x = {1 => "foo", 'a' => true}
      $x
      )) { hash_of(union_of(int32, char), union_of(string, bool)) }
  end

  it "infers type from range literal" do
    assert_type(%(
      require "prelude"

      $x = 1..'a'
      $x
      )) { range_of(int32, char) }
  end

  it "infers type from regex literal" do
    assert_type(%(
      require "prelude"

      $x = /foo/
      $x
      )) { types["Regex"] }
  end

  it "infers type from regex literal with interpolation" do
    assert_type(%(
      require "prelude"

      $x = /foo\#{1}/
      $x
      )) { types["Regex"] }
  end

  it "infers type from tuple literal" do
    assert_type(%(
      $x = {1, "foo"}
      $x
      )) { tuple_of([int32, string]) }
  end

  it "infers type from new expression" do
    assert_type(%(
      class Foo
      end

      $x = Foo.new
      $x
      )) { types["Foo"] }
  end

  it "infers type from new expression of generic" do
    assert_type(%(
      class Foo(T)
      end

      $x = Foo(Int32).new
      $x
      )) { (types["Foo"] as GenericClassType).instantiate([int32] of TypeVar) }
  end

  it "infers type from as" do
    assert_type(%(
      def foo
        1
      end

      $x = foo as Int32
      $x
      )) { int32 }
  end

  it "infers type from static array type declaration" do
    assert_type(%(
      $x : Int8[3]?
      $x
      )) { nilable static_array_of(int8, 3) }
  end

  it "infers type from argument restriction" do
    assert_type(%(
      class Foo
        class Bar
        end

        def foo(z : Bar)
          $x = z
        end
      end

      $x
      )) { nilable types["Foo"].types["Bar"] }
  end

  it "infers type from argument default value" do
    assert_type(%(
      class Foo
        class Bar
        end

        def foo(z = Foo::Bar.new)
          $x = z
        end
      end

      $x
      )) { nilable types["Foo"].types["Bar"] }
  end

  it "infers type from lib fun call" do
    assert_type(%(
      lib LibFoo
        struct Bar
          x : Int32
        end

        fun foo : Bar
      end

      $x = LibFoo.foo
      )) { types["LibFoo"].types["Bar"] }
  end

  it "infers from ||" do
    assert_type(%(
      $x = 1 || true
      )) { union_of(int32, bool) }
  end

  it "infers from &&" do
    assert_type(%(
      $x = 1 && true
      )) { union_of(int32, bool) }
  end

  it "infers from =||" do
    assert_type(%(
      def foo
        $x ||= 1
      end

      $x
      )) { nilable int32 }
  end

  it "infers from if" do
    assert_type(%(
      $x = 1 == 2 ? 1 : true
      )) { union_of(int32, bool) }
  end

  it "infers from begin" do
    assert_type(%(
      $x = begin
        1
        'a'
      end
      )) { char }
  end

  it "infers from assign (1)" do
    assert_type(%(
      $x = $y = 1
      $x
      )) { int32 }
  end

  it "infers from assign (2)" do
    assert_type(%(
      $x = $y = 1
      $y
      )) { int32 }
  end

  it "errors if using typeof in type declaration" do
    assert_error %(
      $x : typeof(1)
      $x
      ),
      "can't use 'typeof' here"
  end

  it "infers type of global reference" do
    assert_type("$foo = 1; def foo; $foo = 'a'; end; foo; $foo") { union_of(int32, char) }
  end

  it "infers type of write global variable when not previously assigned" do
    assert_type("def foo; $foo = 1; end; foo; $foo") { nilable int32 }
  end

  it "types constant depending on global (related to #708)" do
    assert_type(%(
      A = foo

      def foo
        if a = $foo
          a
        else
          $foo = 1
        end
      end

      A
      )) { int32 }
  end

  it "declares global variable" do
    assert_error %(
      $x : Int32
      $x = true
      ),
      "global variable '$x' must be Int32, not Bool"
  end

  it "declares global variable as metaclass" do
    assert_type(%(
      $x : Int32.class
      $x = Int32
      $x
      )) { int32.metaclass }
  end

  it "declares global variable and reads it (nilable)" do
    assert_error %(
      $x : Int32
      $x
      ),
      "global variable '$x' must be Int32, not Nil"
  end

  it "declares global variable and reads it inside method" do
    assert_error %(
      $x : Int32

      def foo
        $x = 1
      end

      if 1 == 2
        foo
      end

      $x
      ),
      "global variable '$x' must be Int32, not Nil"
  end

  it "redefines global variable type" do
    assert_type(%(
      $x : Int32
      $x : Int32 | Float64
      $x = 1
      $x
      )) { union_of int32, float64 }
  end
end
