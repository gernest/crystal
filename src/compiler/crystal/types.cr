require "levenshtein"
require "./syntax/ast"

module Crystal
  # Abstract base class of all types
  abstract class Type
    property doc : String?
    getter locations : Array(Location)?
    setter metaclass : Type?

    def has_attribute?(name)
      false
    end

    def locations
      @locations ||= [] of Location
    end

    def metaclass
      @metaclass ||= begin
        metaclass = MetaclassType.new(program, self)
        initialize_metaclass(metaclass)
        metaclass
      end
    end

    def initialize_metaclass(metaclass)
      # Nothing
    end

    # An opaque id of every type. 0 for Nil, non zero for others, so we can
    # sort types by opaque_id and have Nil in the begining.
    def opaque_id
      self.is_a?(NilType) ? 0_u64 : object_id
    end

    def passed_as_self?
      true
    end

    # Is this type passed by value if it's not a primitive type?
    def passed_by_value?
      false
    end

    def abstract?
      false
    end

    def struct?
      false
    end

    def allowed_in_generics?
      true
    end

    def subclasses
      [] of Type
    end

    def all_subclasses
      [] of Type
    end

    def leaf?
      subclasses.size == 0
    end

    def integer?
      self.is_a?(IntegerType)
    end

    def float?
      self.is_a?(FloatType)
    end

    def class?
      false
    end

    def value?
      false
    end

    def module?
      false
    end

    def metaclass?
      false
    end

    def pointer?
      self.is_a?(PointerInstanceType)
    end

    def primitive_like?
      false
    end

    def nil_type?
      self.is_a?(NilType)
    end

    def bool_type?
      self.is_a?(BoolType)
    end

    def no_return?
      self.is_a?(NoReturnType)
    end

    def virtual?
      self.is_a?(VirtualType)
    end

    def virtual_metaclass?
      self.is_a?(VirtualMetaclassType)
    end

    def fun?
      self.is_a?(FunInstanceType)
    end

    def void?
      self.is_a?(VoidType)
    end

    def reference_like?
      false
    end

    def virtual_type
      self
    end

    def virtual_type!
      self
    end

    def instance_type
      self
    end

    def includes_type?(type)
      self == type
    end

    def instance_of?(type)
      self == type
    end

    def remove_typedef
      self
    end

    def class_var_owner
      self
    end

    def has_in_type_vars?(type)
      false
    end

    def is_implicitly_converted_in_c_to?(expected_type)
      case self
      when NilType
        # nil will be sent as pointer
        expected_type.pointer? || expected_type.fun?
      when FunInstanceType
        # fun will be cast to return void
        expected_type.is_a?(FunInstanceType) && expected_type.return_type == program.void && expected_type.arg_types == self.arg_types
      when NilablePointerType
        # nilable pointer is just a pointer
        self.pointer_type == expected_type
      else
        false
      end
    end

    def allocated?
      true
    end

    def allocated=(value)
      false
    end

    def devirtualize
      self.is_a?(VirtualTypeLookup) ? self.base_type : self
    end

    def implements?(other_type : Type)
      return true if self == other_type

      other_type = other_type.remove_alias
      case other_type
      when UnionType
        other_type.union_types.any? do |union_type|
          implements?(union_type)
        end
      when VirtualType
        implements?(other_type.base_type)
      when VirtualMetaclassType
        implements?(other_type.base_type.metaclass)
      else
        self == other_type
      end
    end

    def covariant?(other_type : Type)
      return true if self == other_type

      case other_type
      when UnionType
        other_type.union_types.any? do |union_type|
          covariant?(union_type)
        end
      else
        false
      end
    end

    def is_subclass_of?(type)
      self == type
    end

    def filter_by(other_type)
      restrict other_type, MatchContext.new(self, self, strict: true)
    end

    def filter_by_responds_to(name)
      nil
    end

    def lookup_def_instance(key)
      raise "Bug: #{self} doesn't implement lookup_def_instance"
    end

    def add_def_instance(key, typed_def)
      raise "Bug: #{self} doesn't implement add_def_instance"
    end

    def instance_var_owner(var_name)
      raise "Bug: #{self} doesn't implement instance_var_owner"
    end

    def add_instance_var_initializer(name, value, meta_vars)
      raise "Bug: #{self} doesn't implement add_instance_var_initializer"
    end

    def declare_instance_var(name, node_or_type)
      raise "Bug: #{self} doesn't implement declare_instance_var"
    end

    def types
      raise "Bug: #{self} has no types"
    end

    def types?
      nil
    end

    def parents
      nil
    end

    def ancestors
      ancestors = [] of Type
      collect_ancestors(ancestors)
      ancestors
    end

    def collect_ancestors(ancestors)
      parents.try &.each do |parent|
        ancestors << parent
        parent.collect_ancestors(ancestors)
      end
    end

    def superclass
      raise "Bug: #{self} doesn't implement superclass"
    end

    def append_to_expand_union_types(types)
      types << self
    end

    def to_s_with_method_name(name)
      case self
      when Program
        name
      when .metaclass?
        "#{self.instance_type}::#{name}"
      else
        "#{self}##{name}"
      end
    end

    def defs
      nil
    end

    def add_def(a_def)
      raise "Bug: #{self} doesn't implement add_def"
    end

    def lookup_defs(name)
      raise "Bug: #{self} doesn't implement lookup_defs"
    end

    def lookup_defs_without_parents(name)
      raise "Bug: #{self} doesn't implement lookup_defs_without_parents"
    end

    def lookup_defs_with_modules(name)
      raise "Bug: #{self} doesn't implement lookup_defs_with_modules"
    end

    def lookup_first_def(name, block)
      raise "Bug: #{self} doesn't implement lookup_first_def"
    end

    def macros
      raise "Bug: #{self} doesn't implement macros"
    end

    def hooks
      nil
    end

    def add_macro(a_def)
      raise "Bug: #{self} doesn't implement add_macro"
    end

    def lookup_macro(name, args_size, named_args)
      raise "Bug: #{self} doesn't implement lookup_macro"
    end

    def lookup_macros(name)
      raise "Bug: #{self} doesn't implement lookup_macros"
    end

    def include(mod)
      raise "Bug: #{self} doesn't implement include"
    end

    def add_including_type(mod)
      raise "Bug: #{self} doesn't implement add_including_type"
    end

    def including_types
      raise "Bug: #{self} doesn't implement including_types"
    end

    def add_subclass_observer(observer)
      raise "Bug: #{self} doesn't implement add_subclass_observer"
    end

    def remove_subclass_observer(observer)
      raise "Bug: #{self} doesn't implement remove_subclass_observer"
    end

    def all_instance_vars
      raise "Bug: #{self} doesn't implement all_instance_vars"
    end

    def owned_instance_vars
      raise "Bug: #{self} doesn't implement owned_instance_vars"
    end

    def index_of_instance_var(name)
      raise "Bug: #{self} doesn't implement index_of_instance_var"
    end

    def index_of_instance_var?(name)
      raise "Bug: #{self} doesn't implement index_of_instance_var?"
    end

    def lookup_instance_var(name, create = true)
      raise "Bug: #{self} doesn't implement lookup_instance_var"
    end

    def lookup_instance_var?(name, create = false)
      raise "Bug: #{self} doesn't implement lookup_instance_var?"
    end

    def owns_instance_var?(name)
      raise "Bug: #{self} doesn't implement owns_instance_var?"
    end

    def has_instance_var_in_initialize?(name)
      raise "Bug: #{self} doesn't implement has_instance_var_in_initialize?"
    end

    def has_instance_var_initializer?(name)
      false
    end

    def has_def?(name)
      raise "Bug: #{self} doesn't implement has_def?"
    end

    def has_def_without_parents?(name)
      raise "Bug: #{self} doesn't implement has_def_without_parents?"
    end

    def remove_instance_var(name)
      raise "Bug: #{self} doesn't implement remove_instance_var"
    end

    def all_instance_vars_count
      raise "Bug: #{self} doesn't implement all_instance_vars_count"
    end

    def add_subclass(subclass)
      raise "Bug: #{self} doesn't implement add_subclass"
    end

    def notify_subclass_added
      raise "Bug: #{self} doesn't implement notify_subclass_added"
    end

    def instance_vars_in_initialize
      raise "Bug: #{self} doesn't implement instance_vars_in_initialize"
    end

    def instance_vars_in_initialize=(value)
      raise "Bug: #{self} doesn't implement instance_vars_in_initialize="
    end

    def depth
      raise "Bug: #{self} doesn't implement depth"
    end

    def name
      raise "Bug: #{self} doesn't implement name"
    end

    def type_desc
      to_s
    end

    def remove_alias
      self
    end

    def remove_alias_if_simple
      self
    end

    def remove_indirection
      self
    end

    def generic_nest
      0
    end

    def has_finalizer?
      return false if struct?

      signature = CallSignature.new "finalize", ([] of Type), nil, nil
      matches = lookup_matches(signature)
      !matches.empty?
    end

    def inspect(io)
      to_s(io)
    end

    def to_s(io)
      to_s_with_options(io)
    end

    abstract def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
  end

  # A type that has a name and can be contained inside other types.
  # For example in `Foo::Bar`, `Foo` is the container and `Bar` is the name.
  #
  # There are other types that have a name but it can be deduced from other(s) type(s),
  # so they don't inherit NamedType: a union type, a metaclass, etc.
  abstract class NamedType < Type
    getter program : Program
    getter container : Type
    getter name : String

    def initialize(@program, @container, @name)
    end

    @types : Hash(String, Type)?

    def types
      @types ||= {} of String => Type
    end

    def types?
      @types
    end

    def append_full_name(io)
      if @container && !@container.is_a?(Program)
        @container.to_s_with_options(io, generic_args: false)
        io << "::"
      end
      io << @name
    end

    def full_name
      String.build { |io| append_full_name(io) }
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      append_full_name(io)
    end
  end

  record CallSignature,
    name : String,
    arg_types : Array(Type),
    block : Block?,
    named_args : Array(NamedArgument)?

  module MatchesLookup
    def lookup_first_def(name, block)
      block = !!block
      if (defs = self.defs) && (list = defs[name]?)
        value = list.find { |item| item.yields == block }
        value.try &.def
      end
    end

    def lookup_defs(name)
      all_defs = [] of Def

      self.defs.try &.[name]?.try &.each do |item|
        all_defs << item.def
      end

      unless name == "new" || name == "initialize"
        parents.try &.each do |parent|
          all_defs.concat parent.lookup_defs(name)
        end
      end

      all_defs
    end

    def lookup_defs_without_parents(name)
      all_defs = [] of Def
      self.defs.try &.[name]?.try &.each do |item|
        all_defs << item.def
      end
      all_defs
    end

    def lookup_defs_with_modules(name)
      if (list = self.defs.try &.[name]?) && !list.empty?
        return list.map(&.def)
      end

      parents.try &.each do |parent|
        next unless parent.module?

        parent_defs = parent.lookup_defs_with_modules(name)
        return parent_defs unless parent_defs.empty?
      end

      [] of Def
    end

    def lookup_macro(name, args_size, named_args)
      if macros = self.macros.try &.[name]?
        match = macros.find &.matches?(args_size, named_args)
        return match if match
      end

      instance_type.parents.try &.each do |parent|
        parent_macro = parent.metaclass.lookup_macro(name, args_size, named_args)
        return parent_macro if parent_macro
      end

      nil
    end

    def lookup_macros(name)
      if macros = self.macros.try &.[name]?
        return macros
      end

      parents.try &.each do |parent|
        parent_macros = parent.lookup_macros(name)
        return parent_macros if parent_macros
      end

      nil
    end
  end

  record DefWithMetadata,
    min_size : Int32,
    max_size : Int32,
    yields : Bool,
    def : Def do
    def self.new(a_def : Def)
      min_size, max_size = a_def.min_max_args_sizes
      new min_size, max_size, !!a_def.yields, a_def
    end
  end

  module DefContainer
    include MatchesLookup

    record Hook,
      kind : Symbol,
      macro : Macro

    getter defs : Hash(String, Array(DefWithMetadata))?
    getter macros : Hash(String, Array(Macro))?
    getter hooks : Array(Hook)?

    def add_def(a_def)
      a_def.owner = self

      if a_def.visibility.public? && a_def.name == "initialize"
        a_def.visibility = Visibility::Protected
      end

      item = DefWithMetadata.new(a_def)

      defs = (@defs ||= {} of String => Array(DefWithMetadata))
      list = defs[a_def.name] ||= [] of DefWithMetadata
      list.each_with_index do |ex_item, i|
        if item.is_restriction_of?(ex_item, self)
          if ex_item.is_restriction_of?(item, self)
            list[i] = item
            a_def.previous = ex_item
            return ex_item.def
          else
            list.insert(i, item)
            return nil
          end
        end
      end
      list << item
      nil
    end

    def add_macro(a_def)
      case a_def.name
      when "inherited"
        return add_hook :inherited, a_def
      when "included"
        return add_hook :included, a_def
      when "extended"
        return add_hook :extended, a_def
      when "method_added"
        return add_hook :method_added, a_def, args_size: 1
      when "method_missing"
        if a_def.args.size != 3 && a_def.args.size != 1
          raise TypeException.new "macro 'method_missing' expects 1 or 3 arguments: (call) or (name, args, block)"
        end
      end

      macros = (@macros ||= {} of String => Array(Macro))
      array = (macros[a_def.name] ||= [] of Macro)
      array.push a_def
    end

    def add_hook(kind, a_def, args_size = 0)
      if a_def.args.size != args_size
        case args_size
        when 0
          raise TypeException.new "macro '#{kind}' must not have arguments"
        when 1
          raise TypeException.new "macro '#{kind}' must have a argument"
        else
          raise TypeException.new "macro '#{kind}' must have #{args_size} arguments"
        end
      end

      hooks = @hooks ||= [] of Hook
      hooks << Hook.new(kind, a_def)
    end

    def filter_by_responds_to(name)
      has_def?(name) ? self : nil
    end

    def has_def?(name)
      return true if has_def_without_parents?(name)

      parents.try &.each do |parent|
        return true if parent.has_def?(name)
      end

      false
    end

    def has_def_without_parents?(name)
      self.defs.try &.has_key?(name)
    end
  end

  record DefInstanceKey,
    def_object_id : UInt64,
    arg_types : Array(Type),
    block_type : Type?,
    named_args : Array({String, Type})?

  module DefInstanceContainer
    @def_instances : Hash(DefInstanceKey, Def)?

    def def_instances
      @def_instances ||= {} of DefInstanceKey => Def
    end

    def add_def_instance(key, typed_def)
      def_instances[key] = typed_def
    end

    def lookup_def_instance(key)
      def_instances[key]?
    end
  end

  abstract class ModuleType < NamedType
    include DefContainer

    @parents : Array(Type)?

    def parents
      @parents ||= [] of Type
    end

    def include(mod)
      if mod == self
        raise TypeException.new "cyclic include detected"
      else
        unless parents.includes?(mod)
          parents.insert 0, mod
          mod.add_including_type(self)
        end
      end
    end

    def implements?(other_type)
      other_type = other_type.remove_alias
      super || parents.any? &.implements?(other_type)
    end

    def covariant?(other_type)
      super || parents.any? &.covariant?(other_type)
    end

    def type_desc
      "module"
    end
  end

  module ClassVarContainer
    @class_vars : Hash(String, MetaTypeVar)?

    def class_vars
      @class_vars ||= {} of String => MetaTypeVar
    end

    def has_class_var?(name)
      class_vars.has_key?(name)
    end

    def lookup_class_var(name)
      class_vars[name] ||= begin
        var = MetaTypeVar.new name
        var.owner = self
        var
      end
    end
  end

  module SubclassObservable
    @subclass_observers : Array(Call)?

    def add_subclass_observer(observer)
      observers = (@subclass_observers ||= [] of Call)
      observers << observer
    end

    def remove_subclass_observer(observer)
      @subclass_observers.try &.delete(observer)
    end

    def notify_subclass_added
      @subclass_observers.try &.dup.each &.on_new_subclass
    end
  end

  module InheritableClass
    include SubclassObservable

    def add_subclass(subclass)
      subclasses << subclass
      notify_subclass_added

      superclass = superclass()
      while superclass
        superclass.notify_subclass_added
        superclass = superclass.superclass
      end
    end
  end

  module InstanceVarInitializerContainer
    class InstanceVarInitializer
      getter name : String
      property value : ASTNode
      getter meta_vars : MetaVars

      def initialize(@name, @value, @meta_vars)
      end
    end

    getter instance_vars_initializers : Array(InstanceVarInitializer)?

    def add_instance_var_initializer(name, value, meta_vars)
      initializers = @instance_vars_initializers ||= [] of InstanceVarInitializer
      initializer = InstanceVarInitializer.new(name, value, meta_vars)
      initializers << initializer
      initializer
    end

    def has_instance_var_initializer?(name)
      @instance_vars_initializers.try(&.any? { |init| init.name == name })
    end
  end

  class NonGenericModuleType < ModuleType
    include DefInstanceContainer
    include ClassVarContainer
    include SubclassObservable

    @including_types : Array(Type)?

    def add_including_type(type)
      including_types = @including_types ||= [] of Type
      including_types.push type

      notify_subclass_added
    end

    def including_types
      if including_types = @including_types
        all_types = Array(Type).new(including_types.size)
        including_types.each do |including_type|
          add_to_including_types(including_type, all_types)
        end
        program.type_merge_union_of(all_types)
      else
        nil
      end
    end

    def raw_including_types
      @including_types
    end

    def append_to_expand_union_types(types)
      if including_types = @including_types
        including_types.each &.append_to_expand_union_types(types)
      else
        types << self
      end
    end

    def remove_indirection
      if including_types = self.including_types
        including_types.remove_indirection
      else
        self
      end
    end

    def add_to_including_types(type : GenericType, all_types)
      type.generic_types.each_value do |generic_type|
        all_types << generic_type unless all_types.includes?(generic_type)
      end
      type.subclasses.each do |subclass|
        add_to_including_types subclass, all_types
      end
    end

    def add_to_including_types(type, all_types)
      virtual_type = type.virtual_type
      all_types << virtual_type unless all_types.includes?(virtual_type)
    end

    def filter_by_responds_to(name)
      including_types.try &.filter_by_responds_to(name)
    end

    def passed_by_value?
      including_types = including_types()
      if including_types
        including_types.passed_by_value?
      else
        false
      end
    end

    def module?
      true
    end

    def declare_instance_var(name, var_type : Type)
      @including_types.try &.each do |type|
        case type
        when Program, FileModule
          # skip
        when NonGenericModuleType
          type.declare_instance_var(name, var_type)
        when NonGenericClassType
          type.declare_instance_var(name, var_type)
        end
      end
    end

    def add_instance_var_initializer(name, value, meta_vars)
      @including_types.try &.each do |type|
        case type
        when Program, FileModule
          # skip
        when NonGenericModuleType
          type.add_instance_var_initializer(name, value, meta_vars)
        when NonGenericClassType
          type.add_instance_var_initializer(name, value, meta_vars)
        end
      end
    end
  end

  # A module that is related to a file and contains its private defs.
  class FileModule < NonGenericModuleType
    @vars : MetaVars?

    def vars
      @vars ||= MetaVars.new
    end

    def vars?
      @vars
    end

    def passed_as_self?
      false
    end
  end

  abstract class ClassType < ModuleType
    include InheritableClass
    include InstanceVarInitializerContainer

    getter superclass : Type?
    getter subclasses : Array(Type)
    getter depth : Int32
    property? abstract : Bool
    property? struct : Bool
    getter owned_instance_vars : Set(String)
    property instance_vars_in_initialize : Set(String)?
    getter? allocated : Bool
    property? allowed_in_generics : Bool

    def initialize(program, container, name, @superclass, add_subclass = true)
      super(program, container, name)
      if superclass
        @depth = superclass.depth + 1
      else
        @depth = 0
      end
      @subclasses = [] of Type
      @abstract = false
      @struct = false
      @allocated = false
      @owned_instance_vars = Set(String).new
      @allowed_in_generics = true
      parents.push superclass if superclass
      force_add_subclass if add_subclass
    end

    def force_add_subclass
      superclass.try &.add_subclass(self)
    end

    def all_subclasses
      subclasses = [] of Type
      append_subclasses(self, subclasses)
      subclasses
    end

    def append_subclasses(type, subclasses)
      type.subclasses.each do |subclass|
        subclasses << subclass
        append_subclasses subclass, subclasses
      end
    end

    def is_subclass_of?(type)
      super || superclass.try &.is_subclass_of?(type)
    end

    def add_def(a_def)
      super

      transfer_instance_vars a_def

      a_def
    end

    def transfer_instance_vars(a_def)
      # Don't consider macro defs here (only later, when expanded)
      return if a_def.macro_def?

      is_initialize = a_def.name == "initialize"

      if a_def_instance_vars = a_def.instance_vars
        a_def_instance_vars.each do |ivar|
          if superclass = superclass()
            unless superclass.owns_instance_var?(ivar)
              unless owned_instance_vars.includes?(ivar)
                owned_instance_vars.add(ivar)
                all_subclasses.each do |subclass|
                  subclass.remove_instance_var(ivar)
                end
              end
            end
          end
        end

        if is_initialize
          unless a_def.calls_initialize
            if ivii = @instance_vars_in_initialize
              @instance_vars_in_initialize = ivii & a_def_instance_vars
            else
              @instance_vars_in_initialize = a_def_instance_vars
            end
          end

          unless a_def.calls_super
            sup = superclass
            while sup
              sup_ivars = sup.instance_vars_in_initialize
              if sup_ivars
                sup.instance_vars_in_initialize = sup_ivars & a_def_instance_vars
              end
              sup = sup.superclass
            end
          end
        end
      elsif is_initialize
        # If it's an initialize without instance variables,
        # then *all* instance variables are nilable
        unless a_def.calls_initialize
          @instance_vars_in_initialize = Set(String).new
        end

        unless a_def.calls_super
          sup = superclass
          while sup
            sup.instance_vars_in_initialize = Set(String).new
            sup = sup.superclass
          end
        end
      end
    end

    def transfer_instance_vars_of_mod(mod)
      if (defs = mod.defs)
        defs.each do |def_name, list|
          list.each do |item|
            transfer_instance_vars item.def
          end
        end
      end

      mod.parents.try &.each do |parent|
        transfer_instance_vars_of_mod parent
      end
    end

    def include(mod)
      super mod
      transfer_instance_vars_of_mod mod
    end

    def allocated=(allocated)
      @allocated = allocated
      superclass.try &.allocated = allocated
    end

    def struct?
      @struct
    end

    def passed_by_value?
      struct?
    end

    def type_desc
      struct? ? "struct" : "class"
    end
  end

  module InstanceVarContainer
    @instance_vars : Hash(String, MetaTypeVar)?

    def instance_vars
      @instance_vars ||= {} of String => MetaTypeVar
    end

    def owns_instance_var?(name)
      owned_instance_vars.includes?(name) || superclass.try &.owns_instance_var?(name)
    end

    def instance_var_owner(name)
      if owned_instance_vars.includes?(name)
        self
      else
        superclass.try &.instance_var_owner(name)
      end
    end

    def remove_instance_var(name)
      owned_instance_vars.delete(name)
      instance_vars.delete(name)
    end

    def lookup_instance_var(name, create = true)
      lookup_instance_var?(name, create).not_nil!
    end

    def lookup_instance_var?(name, create)
      if var = superclass.try &.lookup_instance_var?(name, false)
        return var
      end

      if create || owned_instance_vars.includes?(name)
        instance_vars[name] ||= MetaTypeVar.new(name).tap { |v| v.owner = self }
      else
        instance_vars[name]?
      end
    end

    def index_of_instance_var(name)
      index_of_instance_var?(name).not_nil!
    end

    def index_of_instance_var?(name)
      if sup = superclass
        index = sup.index_of_instance_var?(name)
        if index
          index
        else
          index = instance_vars.key_index(name)
          if index
            sup.all_instance_vars_count + index
          else
            nil
          end
        end
      else
        instance_vars.key_index(name)
      end
    end

    def each_instance_var(&block)
      superclass.try &.each_instance_var &block
      instance_vars.each(&block)
    end

    def all_instance_vars
      if sup = superclass
        sup.all_instance_vars.merge(instance_vars)
      else
        instance_vars
      end
    end

    def all_instance_vars_count
      if sup = superclass
        sup.all_instance_vars_count + instance_vars.size
      else
        instance_vars.size
      end
    end

    def has_instance_var_in_initialize?(name)
      instance_vars_initializers.try(&.any? { |init| init.name == name }) ||
        instance_vars_in_initialize.try(&.includes?(name)) ||
        superclass.try &.has_instance_var_in_initialize?(name)
    end
  end

  class NonGenericClassType < ClassType
    include InstanceVarContainer
    include ClassVarContainer
    include DefInstanceContainer

    def initialize_metaclass(metaclass)
      metaclass.add_def Def.new("allocate", body: Primitive.new(:allocate))
    end

    def virtual_type
      if leaf? && !self.abstract?
        self
      elsif struct?
        self
      else
        virtual_type!
      end
    end

    @virtual_type : VirtualType?

    def virtual_type!
      @virtual_type ||= VirtualType.new(program, self)
    end

    def class?
      true
    end

    def reference_like?
      !struct?
    end

    def declare_instance_var(name, type : Type)
      ivar = lookup_instance_var(name)
      ivar.type = type
      ivar.bind_to ivar
      ivar.freeze_type = type
    end

    def declare_instance_var(name, node : ASTNode)
      visitor = TypeLookup.new(self)
      node.accept visitor

      ivar = lookup_instance_var(name, create: true)
      ivar.type = visitor.type
      ivar.bind_to ivar
      ivar.freeze_type = visitor.type.virtual_type
    end

    def covariant?(other_type)
      other_type = other_type.base_type if other_type.is_a?(VirtualType)
      is_subclass_of?(other_type) || super
    end

    def add_instance_var_initializer(name, value, meta_vars)
      super

      var = lookup_instance_var(name, true)
      var.bind_to(value)

      program.after_inference_types << self
    end
  end

  class PrimitiveType < ClassType
    include DefInstanceContainer
    include ClassVarContainer

    getter bytes : Int32

    def initialize(program, container, name, superclass, @bytes : Int32)
      super(program, container, name, superclass)
      self.struct = true
    end

    def value?
      true
    end

    def primitive_like?
      true
    end

    def passed_by_value?
      false
    end

    def allocated?
      true
    end

    def abstract?
      false
    end

    def hierarcy_type
      self
    end
  end

  class BoolType < PrimitiveType
  end

  class CharType < PrimitiveType
  end

  class IntegerType < PrimitiveType
    getter rank : Int32
    getter kind : Symbol

    def initialize(program, container, name, superclass, bytes, @rank, @kind)
      super(program, container, name, superclass, bytes)
    end

    def signed?
      @rank % 2 == 1
    end

    def unsigned?
      @rank % 2 == 0
    end

    def bits
      8 * (2 ** normal_rank)
    end

    def normal_rank
      (@rank - 1) / 2
    end
  end

  class FloatType < PrimitiveType
    getter rank : Int32

    def initialize(program, container, name, superclass, bytes, @rank)
      super(program, container, name, superclass, bytes)
    end

    def kind
      @bytes == 4 ? :f32 : :f64
    end
  end

  class SymbolType < PrimitiveType
  end

  class NilType < PrimitiveType
    def reference_like?
      true
    end
  end

  abstract class EmptyType < Type
    getter program : Program

    def initialize(@program)
    end

    def lookup_defs(name)
      [] of Def
    end

    def lookup_defs_without_parents(name)
      [] of Def
    end

    def parents
      nil
    end

    def allocated?
      true
    end

    def abstract?
      false
    end
  end

  class NoReturnType < EmptyType
    def primitive_like?
      true
    end

    # NoReturn can be assigned to any other type (because it never will)
    def implements?(other_type)
      true
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      io << "NoReturn"
    end
  end

  class VoidType < EmptyType
    def primitive_like?
      true
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      io << "Void"
    end
  end

  alias TypeVar = Type | ASTNode

  module GenericType
    getter type_vars : Array(String)
    property variadic : Bool
    @variadic = false

    @generic_types : Hash(Array(TypeVar), Type)?

    def generic_types
      @generic_types ||= {} of Array(TypeVar) => Type
    end

    def instantiate(type_vars)
      if (instance = generic_types[type_vars]?)
        return instance
      end

      instance_type_vars = {} of String => ASTNode
      last_index = self.type_vars.size - 1
      self.type_vars.each_with_index do |name, index|
        if variadic && index == last_index
          types = [] of TypeVar
          index.upto(type_vars.size - 1) do |second_index|
            types << type_vars[second_index]
          end
          tuple_type = program.tuple.instantiate(types) as TupleInstanceType
          instance_type_vars[name] = tuple_type.var
        else
          type_var = type_vars[index]
          case type_var
          when Type
            var = Var.new(name, type_var)
            var.bind_to var
            instance_type_vars[name] = var
          when ASTNode
            instance_type_vars[name] = type_var
          end
        end
      end

      instance = self.new_generic_instance(program, self, instance_type_vars)
      run_instance_vars_initializers self, self, instance

      generic_types[type_vars] = instance
      initialize_instance instance

      instance.after_initialize

      # Notify modules that an instance was added
      notify_parent_modules_subclass_added(self)

      instance
    end

    def notify_parent_modules_subclass_added(type)
      type.parents.try &.each do |parent|
        parent.notify_subclass_added if parent.is_a?(NonGenericModuleType)
        notify_parent_modules_subclass_added parent
      end
    end

    @inherited : Array(Type)?

    def add_inherited(type)
      inherited = @inherited ||= [] of Type
      inherited << type
    end

    def add_instance_var_initializer(name, value, meta_vars)
      initializer = super

      # Make sure to type the initializer for existing instantiations
      generic_types.each_value do |instance|
        run_instance_var_initializer(initializer, instance)
      end

      @inherited.try &.each do |inherited|
        run_instance_var_initializer(initializer, inherited)
        if inherited.is_a?(GenericClassType)
          inherited.add_instance_var_initializer(name, value, meta_vars)
        end
      end

      initializer
    end

    def run_instance_vars_initializers(real_type, type : GenericClassType | ClassType, instance)
      if superclass = type.superclass
        run_instance_vars_initializers(real_type, superclass, instance)
      end

      type.instance_vars_initializers.try &.each do |initializer|
        run_instance_var_initializer initializer, instance
      end
    end

    def run_instance_vars_initializers(real_type, type : InheritedGenericClass, instance)
      run_instance_vars_initializers real_type, type.extended_class, instance
    end

    def run_instance_vars_initializers(real_type, type, instance)
      # Nothing
    end

    def run_instance_var_initializer(initializer, instance : GenericClassInstanceType | NonGenericClassType)
      meta_vars = MetaVars.new
      visitor = MainVisitor.new(program, vars: meta_vars, meta_vars: meta_vars)
      visitor.scope = instance
      value = initializer.value.clone
      value.accept visitor
      instance_var = instance.lookup_instance_var(initializer.name)
      instance_var.bind_to(value)
      instance.add_instance_var_initializer(initializer.name, value, meta_vars)
    end

    def run_instance_var_initializer(initializer, instance)
      # Nothing
    end

    def initialize_instance(instance)
      # Nothing
    end
  end

  class GenericModuleType < ModuleType
    include GenericType

    def initialize(program, container, name, @type_vars)
      super(program, container, name)
    end

    def module?
      true
    end

    def allowed_in_generics?
      false
    end

    def type_desc
      "generic module"
    end

    @including_types : Array(Type)?

    def add_including_type(type)
      including_types = @including_types ||= [] of Type
      including_types.push type
    end

    def raw_including_types
      @including_types
    end

    @declared_instance_vars : Hash(String, ASTNode)?

    def declare_instance_var(name, node : ASTNode)
      declared_instance_vars = (@declared_instance_vars ||= {} of String => ASTNode)
      declared_instance_vars[name] = node

      @inherited.try &.each do |inherited|
        inherited.declare_instance_var(name, node)
      end
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      super
      if generic_args
        io << "("
        type_vars.each_with_index do |type_var, i|
          io << ", " if i > 0
          type_var.to_s(io)
        end
        io << ")"
      end
    end
  end

  class GenericClassType < ClassType
    include GenericType
    include DefInstanceContainer

    @type_vars : Array(String)

    def initialize(program, container, name, superclass, @type_vars, add_subclass = true)
      super(program, container, name, superclass, add_subclass)
      @variadic = false
      @allocated = true
    end

    def class?
      true
    end

    def allocated=(value)
      superclass.try &.allocated = value
    end

    def allowed_in_generics?
      false
    end

    def new_generic_instance(program, generic_type, type_vars)
      GenericClassInstanceType.new program, generic_type, type_vars
    end

    @declared_instance_vars : Hash(String, ASTNode)?

    def declare_instance_var(name, node : ASTNode)
      declared_instance_vars = (@declared_instance_vars ||= {} of String => ASTNode)
      declared_instance_vars[name] = node

      generic_types.each do |key, instance|
        instance.declare_instance_var(name, node)
      end

      @inherited.try &.each do |inherited|
        inherited.declare_instance_var(name, node)
      end
    end

    def initialize_instance(instance)
      if decl_ivars = @declared_instance_vars
        visitor = TypeLookup.new(instance)
        decl_ivars.each do |name, node|
          node.accept visitor

          ivar = MetaTypeVar.new(name, visitor.type)
          ivar.owner = instance
          ivar.bind_to ivar
          ivar.freeze_type = visitor.type
          instance.instance_vars[name] = ivar
        end
      end
    end

    def initialize_metaclass(metaclass)
      metaclass.add_def Def.new("allocate", body: Primitive.new(:allocate))
    end

    def has_instance_var_in_initialize?(name)
      instance_vars_initializers.try(&.any? { |init| init.name == name }) ||
        instance_vars_in_initialize.try(&.includes?(name)) ||
        superclass.try &.has_instance_var_in_initialize?(name)
    end

    def type_desc
      struct? ? "generic struct" : "generic class"
    end

    def including_types
      instances = generic_types.values
      subclasses.each do |subclass|
        if subclass.is_a?(GenericClassType)
          subtypes = subclass.including_types
          instances << subtypes if subtypes
        else
          instances << subclass
        end
      end
      program.union_of instances
    end

    def remove_indirection
      if including_types = self.including_types
        including_types.remove_indirection
      else
        self
      end
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      super
      if generic_args
        io << "("
        type_vars.each_with_index do |type_var, i|
          io << ", " if i > 0
          type_var.to_s(io)
        end
        io << ")"
      end
    end
  end

  class GenericClassInstanceType < Type
    include InheritableClass
    include InstanceVarContainer
    include InstanceVarInitializerContainer
    include ClassVarContainer
    include DefInstanceContainer
    include MatchesLookup

    getter program : Program
    getter generic_class # : GenericClassType
    getter type_vars : Hash(String, ASTNode)
    getter subclasses : Array(Type)
    getter? allocated : Bool
    getter generic_nest : Int32

    def initialize(@program, @generic_class, @type_vars, generic_nest = nil)
      @subclasses = [] of Type
      @allocated = false
      @generic_nest = generic_nest || (1 + @type_vars.values.max_of { |node| node.type?.try(&.generic_nest) || 0 })
    end

    def after_initialize
      @generic_class.superclass.not_nil!.add_subclass(self)
    end

    def parents
      generic_class.parents.map do |t|
        case t
        when IncludedGenericModule
          IncludedGenericModule.new(program, t.module, self, t.mapping)
        when InheritedGenericClass
          InheritedGenericClass.new(program, t.extended_class, t.mapping, self)
        else
          t
        end
      end
    end

    def virtual_type
      self
    end

    delegate leaf?, @generic_class
    delegate depth, @generic_class
    delegate defs, @generic_class
    delegate superclass, @generic_class
    delegate owned_instance_vars, @generic_class
    delegate instance_vars_in_initialize, @generic_class
    delegate macros, @generic_class
    delegate :abstract?, @generic_class
    delegate struct?, @generic_class
    delegate passed_by_value?, @generic_class
    delegate type_desc, @generic_class

    def allocated=(allocated)
      @allocated = allocated
      superclass.try { |s| s.allocated = allocated }
    end

    def declare_instance_var(name, node : ASTNode)
      visitor = TypeLookup.new(self)
      node.accept visitor

      ivar = MetaTypeVar.new(name, visitor.type)
      ivar.owner = self
      ivar.bind_to ivar
      ivar.freeze_type = visitor.type.virtual_type
      self.instance_vars[name] = ivar
    end

    def filter_by_responds_to(name)
      @generic_class.filter_by_responds_to(name) ? self : nil
    end

    def class?
      true
    end

    def reference_like?
      !struct?
    end

    def metaclass
      @metaclass ||= GenericClassInstanceMetaclassType.new(program, self)
    end

    def is_subclass_of?(type)
      super || generic_class.is_subclass_of?(type)
    end

    def implements?(other_type)
      other_type = other_type.remove_alias
      super || generic_class.implements?(other_type)
    end

    def covariant?(other_type)
      if other_type.is_a?(GenericClassInstanceType)
        super
      else
        implements?(other_type)
      end
    end

    def has_in_type_vars?(type)
      type_vars.each_value do |type_var|
        case type_var
        when Var
          return true if type_var.type.includes_type?(type) || type_var.type.has_in_type_vars?(type)
        when Type
          return true if type_var.includes_type?(type) || type_var.has_in_type_vars?(type)
        end
      end
      false
    end

    def add_instance_var_initializer(name, value, meta_vars)
      super

      program.after_inference_types << self
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      generic_class.append_full_name(io)
      io << "("
      i = 0
      type_vars.each_value do |type_var|
        io << ", " if i > 0
        if type_var.is_a?(Var)
          type_var.type.to_s_with_options(io, skip_union_parens: true)
        else
          type_var.to_s(io)
        end
        i += 1
      end
      io << ")"
    end
  end

  class PointerType < GenericClassType
    def new_generic_instance(program, generic_type, type_vars)
      PointerInstanceType.new program, generic_type, type_vars
    end

    def type_desc
      "generic struct"
    end
  end

  class PointerInstanceType < GenericClassInstanceType
    def var
      type_vars["T"]
    end

    def element_type
      var.type
    end

    def reference_like?
      false
    end

    def allocated?
      true
    end

    def primitive_like?
      var.type.primitive_like?
    end

    def passed_by_value?
      false
    end

    def type_desc
      "struct"
    end
  end

  class StaticArrayType < GenericClassType
    def new_generic_instance(program, generic_type, type_vars)
      n = type_vars["N"]
      unless n.is_a?(NumberLiteral)
        raise TypeException.new "can't instantiate StaticArray(T, N) with N = #{n.type} (N must be an integer)"
      end

      value = n.value.to_i
      if value < 0
        raise TypeException.new "can't instantiate StaticArray(T, N) with N = #{value} (N must be positive)"
      end

      StaticArrayInstanceType.new program, generic_type, type_vars
    end
  end

  class StaticArrayInstanceType < GenericClassInstanceType
    def var
      type_vars["T"]
    end

    def size
      type_vars["N"]
    end

    def element_type
      var.type
    end

    def allocated?
      true
    end

    def primitive_like?
      var.type.primitive_like?
    end

    def reference_like?
      false
    end
  end

  class TupleType < GenericClassType
    def initialize(program, container, name, superclass, type_vars, add_subclass = true)
      super
      @variadic = true
      @struct = true
    end

    def instantiate(type_vars)
      if (instance = generic_types[type_vars]?)
        return instance
      end

      types = type_vars.map do |type_var|
        unless type_var.is_a?(Type)
          type_var.raise "argument to Tuple must be a type, not #{type_var}"
        end
        type_var
      end
      instance = TupleInstanceType.new(program, types)
      generic_types[type_vars] = instance
      initialize_instance instance
      instance.after_initialize
      instance
    end

    def new_generic_instance(program, generic_type, type_vars)
      raise "Bug: TupleType#new_generic_instance shouldn't be invoked"
    end

    def type_desc
      "tuple"
    end
  end

  class TupleInstanceType < GenericClassInstanceType
    getter tuple_types : Array(Type)

    def initialize(program, @tuple_types)
      generic_nest = 1 + (@tuple_types.empty? ? 0 : @tuple_types.max_of(&.generic_nest))
      var = Var.new("T", self)
      var.bind_to var
      super(program, program.tuple, {"T" => var} of String => ASTNode, generic_nest)
    end

    @tuple_indexers : Hash(Int32, Def)?

    def tuple_indexer(index)
      indexers = @tuple_indexers ||= {} of Int32 => Def
      tuple_indexer(indexers, index)
    end

    @tuple_metaclass_indexers : Hash(Int32, Def)?

    def tuple_metaclass_indexer(index)
      indexers = @tuple_metaclass_indexers ||= {} of Int32 => Def
      tuple_indexer(indexers, index)
    end

    private def tuple_indexer(indexers, index)
      indexers[index] ||= begin
        indexer = Def.new("[]", [Arg.new("index")], TupleIndexer.new(index))
        indexer.owner = self
        indexer
      end
    end

    def var
      type_vars["T"]
    end

    def primitive_like?
      true
    end

    def reference_like?
      false
    end

    def passed_by_value?
      true
    end

    def allocated?
      true
    end

    def has_in_type_vars?(type)
      tuple_types.any? { |tuple_type| tuple_type.includes_type?(type) || tuple_type.has_in_type_vars?(type) }
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      io << "{"
      @tuple_types.each_with_index do |tuple_type, i|
        io << ", " if i > 0
        tuple_type.to_s_with_options(io, skip_union_parens: true)
      end
      io << "}"
    end

    def type_desc
      "tuple"
    end
  end

  class IncludedGenericModule < Type
    include MatchesLookup

    getter program : Program
    getter module : GenericModuleType
    getter including_class : Type
    getter mapping : Hash(String, ASTNode)

    def initialize(@program, @module, @including_class, @mapping)
    end

    def add_including_type(type)
      @module.add_including_type type
    end

    delegate container, @module
    delegate name, @module
    delegate defs, @module
    delegate macros, @module
    delegate implements?, @module
    delegate lookup_defs, @module
    delegate lookup_defs_with_modules, @module
    delegate lookup_macro, @module
    delegate lookup_macros, @module
    delegate has_def?, @module
    delegate metaclass, @module

    def instance_of?(type)
      type == @module
    end

    def parents
      @module.parents.map do |t|
        case t
        when IncludedGenericModule
          IncludedGenericModule.new(program, t.module, self, t.mapping)
        when InheritedGenericClass
          InheritedGenericClass.new(program, t.extended_class, t.mapping, self)
        else
          t
        end
      end
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      @module.to_s(io)
      io << "("
      @including_class.to_s(io)
      io << ")"
      io << @mapping
    end
  end

  class InheritedGenericClass < Type
    include MatchesLookup

    getter program : Program
    getter extended_class : Type
    property! extending_class : Type
    getter mapping : Hash(String, ASTNode)

    def initialize(@program, @extended_class, @mapping, @extending_class = nil)
    end

    def metaclass
      @metaclass ||= InheritedGenericClass.new(@program, @extended_class.metaclass, @mapping, @extending_class)
    end

    def type_vars
      mapping.keys
    end

    def instance_of?(type)
      type == @extended_class
    end

    delegate depth, @extended_class
    delegate superclass, @extended_class
    delegate add_subclass, @extended_class
    delegate container, @extended_class
    delegate name, @extended_class
    delegate defs, @extended_class
    delegate macros, @extended_class
    delegate implements?, @extended_class
    delegate lookup_defs, @extended_class
    delegate lookup_defs_with_modules, @extended_class
    delegate lookup_macro, @extended_class
    delegate lookup_macros, @extended_class
    delegate has_def?, @extended_class
    delegate has_instance_var_in_initialize?, @extended_class
    delegate instance_vars_in_initialize, @extended_class
    delegate :"instance_vars_in_initialize=", @extended_class
    delegate :"allocated=", @extended_class
    delegate notify_subclass_added, @extended_class
    delegate has_def_without_parents?, @extended_class
    delegate add_def, @extended_class

    def lookup_instance_var?(name, create = false)
      nil
    end

    def all_instance_vars
      {} of String => Var
    end

    def index_of_instance_var?(name)
      nil
    end

    def all_instance_vars_count
      0
    end

    def owns_instance_var?(name)
      false
    end

    def parents
      @extended_class.parents.try &.map do |t|
        case t
        when IncludedGenericModule
          IncludedGenericModule.new(program, t.module, self, t.mapping)
        when InheritedGenericClass
          InheritedGenericClass.new(program, t.extended_class, t.mapping, self)
        else
          t
        end
      end
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      @extended_class.to_s(io)
      io << "("
      @extending_class.to_s(io)
      io << ")"
      io << @mapping
    end
  end

  class LibType < ModuleType
    getter link_attributes : Array(LinkAttribute)?
    property? used : Bool

    def initialize(program, container, name)
      super(program, container, name)
      @used = false
    end

    def add_link_attributes(link_attributes)
      if link_attributes
        my_link_attributes = @link_attributes ||= [] of LinkAttribute
        link_attributes.each do |attr|
          my_link_attributes << attr unless my_link_attributes.includes?(attr)
        end
      end
    end

    def metaclass
      self
    end

    def add_def(a_def : External)
      if defs = self.defs
        if existing_defs = defs[a_def.name]?
          existing = existing_defs.first?
          if existing
            existing = existing.def as External
            unless existing.compatible_with?(a_def)
              raise TypeException.new "fun redefinition with different signature (was #{existing})"
            end
          end
        end
      end

      super
    end

    def add_def(a_def : Def)
      raise "Bug: shouldn't be adding a Def in a LibType"
    end

    def add_var(name, type, real_name, attributes)
      setter = External.new("#{name}=", [Arg.new("value", type: type)], Primitive.new(:external_var_set, type), real_name)
      setter.set_type(type)
      setter.attributes = attributes

      getter = External.new("#{name}", [] of Arg, Primitive.new(:external_var_get, type), real_name)
      getter.set_type(type)
      getter.attributes = attributes

      add_def setter
      add_def getter
    end

    def passed_as_self?
      false
    end

    def type_desc
      "lib"
    end
  end

  class TypeDefType < NamedType
    include DefInstanceContainer
    include MatchesLookup

    getter typedef # : Type


    def initialize(program, container, name, @typedef)
      super(program, container, name)
    end

    def remove_typedef
      typedef.remove_typedef
    end

    def remove_indirection
      typedef.remove_indirection
    end

    delegate pointer?, typedef
    delegate defs, typedef
    delegate macros, typedef
    delegate passed_by_value?, typedef
    delegate reference_like?, typedef

    def parents
      # We need to repoint "self" in included generic modules to this typedef,
      # so "self" restrictions match and don't point to the typdefed type.
      typedef_parents = typedef.parents.try(&.dup) || [] of Type

      if typedef_parents
        typedef_parents.each_with_index do |t, i|
          case t
          when IncludedGenericModule
            typedef_parents[i] = IncludedGenericModule.new(program, t.module, self, t.mapping)
          when InheritedGenericClass
            typedef_parents[i] = InheritedGenericClass.new(program, t.extended_class, t.mapping, self)
          end
        end
      end

      typedef_parents
    end

    def primitive_like?
      true
    end

    def type_def_type?
      true
    end

    def type_desc
      "type def"
    end
  end

  class AliasType < NamedType
    getter? value_processed : Bool

    # @value : ASTNode
    @aliased_type : Type?
    @simple : Bool

    def initialize(program, container, name, @value)
      super(program, container, name)
      @simple = true
      @value_processed = false
    end

    delegate lookup_defs, aliased_type
    delegate lookup_defs_with_modules, aliased_type
    delegate lookup_first_def, aliased_type
    delegate def_instances, aliased_type
    delegate add_def_instance, aliased_type
    delegate lookup_def_instance, aliased_type
    delegate lookup_macro, aliased_type
    delegate lookup_macros, aliased_type
    delegate cover, aliased_type
    delegate cover_size, aliased_type
    delegate passed_by_value?, aliased_type

    def aliased_type
      aliased_type?.not_nil!
    end

    def aliased_type?
      process_value
      @aliased_type
    end

    def remove_alias
      process_value
      if aliased_type = @aliased_type
        aliased_type.remove_alias
      else
        @simple = false
        self
      end
    end

    def remove_alias_if_simple
      process_value
      if @simple
        remove_alias
      else
        self
      end
    end

    def remove_indirection
      process_value
      if aliased_type = @aliased_type
        aliased_type.remove_indirection
      else
        @simple = false
        self
      end
    end

    def allowed_in_generics?
      process_value
      if aliased_type = @aliased_type
        aliased_type.remove_alias.allowed_in_generics?
      else
        true
      end
    end

    def process_value
      return if @value_processed
      @value_processed = true

      visitor = TopLevelVisitor.new(@program)
      visitor.types.push(container)
      visitor.processing_types do
        @value.accept visitor
      end

      @aliased_type = @value.type.instance_type
    end

    def type_desc
      "alias"
    end
  end

  abstract class CStructOrUnionType < NonGenericClassType
    include DefContainer
    include DefInstanceContainer

    getter vars : Hash(String, MetaTypeVar)

    def initialize(program, container, name)
      super(program, container, name, program.struct)
      @vars = {} of String => MetaTypeVar
      @struct = true
      @allocated = true
    end

    def passed_by_value?
      true
    end

    def primitive_like?
      true
    end

    def has_var?(name)
      @vars.has_key?(name)
    end

    def has_instance_var_in_initialize?(name)
      true
    end

    def lookup_instance_var(name, create = nil)
      lookup_instance_var?(name).not_nil!
    end

    def lookup_instance_var?(name, create = nil)
      @vars[remove_at_from_var_name(name)]
    end

    def all_instance_vars
      @vars
    end

    def index_of_var(name)
      @vars.key_index(remove_at_from_var_name(name)).not_nil!
    end

    def index_of_instance_var(name)
      index_of_var(name)
    end

    private def remove_at_from_var_name(name)
      name.starts_with?('@') ? name[1..-1] : name
    end
  end

  class CStructType < CStructOrUnionType
    property packed : Bool
    @packed = false

    def add_var(var)
      @vars[var.name] = var
      add_def Def.new("#{var.name}=", [Arg.new("value")], Primitive.new(:struct_set))
      add_def Def.new(var.name, body: Primitive.new(:struct_get))
    end

    def initialize_metaclass(metaclass)
      metaclass.add_def Def.new("new", body: Primitive.new(:struct_new))
    end

    def has_attribute?(name)
      return true if packed && name == "Packed"
      false
    end

    def type_desc
      "struct"
    end
  end

  class CUnionType < CStructOrUnionType
    def add_var(var)
      @vars[var.name] = var
      add_def Def.new("#{var.name}=", [Arg.new("value")], Primitive.new(:union_set))
      add_def Def.new(var.name, body: Primitive.new(:union_get))
    end

    def initialize_metaclass(metaclass)
      metaclass.add_def Def.new("new", body: Primitive.new(:union_new))
    end

    def type_desc
      "union"
    end
  end

  class EnumType < NamedType
    include DefContainer
    include DefInstanceContainer
    include ClassVarContainer

    getter base_type : IntegerType
    getter? flags : Bool

    def initialize(program, container, name, @base_type, flags)
      super(program, container, name)

      @flags = !!flags

      add_def Def.new("value", [] of Arg, Primitive.new(:enum_value, @base_type))
      metaclass.add_def Def.new("new", [Arg.new("value", type: @base_type)], Primitive.new(:enum_new, self))
    end

    @parents : Array(Type)?

    def parents
      @parents ||= [program.enum] of Type
    end

    def add_constant(constant)
      types[constant.name] = Const.new(program, self, constant.name, constant.default_value.not_nil!)
    end

    def has_attribute?(name)
      return true if flags? && name == "Flags"
      false
    end

    def primitive_like?
      true
    end

    def type_desc
      "enum"
    end
  end

  class MetaclassType < ClassType
    include DefContainer
    include DefInstanceContainer
    include ClassVarContainer
    include InstanceVarContainer

    getter program : Program
    getter instance_type # : Type


    def initialize(@program, instance_type : Type, super_class = nil, name = nil)
      @instance_type = instance_type
      super_class ||= if instance_type.is_a?(ClassType) && instance_type.superclass
                        instance_type.superclass.not_nil!.metaclass
                      elsif instance_type.is_a?(EnumType)
                        @program.enum.metaclass
                      else
                        @program.class_type
                      end
      unless name
        if instance_type.module?
          name = "#{@instance_type}:Module"
        else
          name = "#{@instance_type}:Class"
        end
      end
      super(@program, @program, name, super_class)
    end

    def allocated?
      true
    end

    def metaclass
      @program.class_type
    end

    delegate :abstract?, instance_type
    delegate :generic_nest, instance_type

    def class_var_owner
      instance_type
    end

    def metaclass?
      true
    end

    def passed_as_self?
      false
    end

    def virtual_type
      instance_type.virtual_type.metaclass
    end

    def virtual_type!
      instance_type.virtual_type!.metaclass
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      io << @name
    end
  end

  class GenericClassInstanceMetaclassType < Type
    include MatchesLookup
    include DefInstanceContainer

    getter program : Program
    getter instance_type : GenericClassInstanceType

    def initialize(@program, instance_type)
      @instance_type = instance_type
    end

    @parents : Array(Type)?

    def parents
      @parents ||= begin
        parents = [] of Type
        parents << (instance_type.superclass.try(&.metaclass) || @program.class_type)
        parents
      end
    end

    delegate add_def, instance_type.generic_class.metaclass
    delegate defs, instance_type.generic_class.metaclass
    delegate macros, instance_type.generic_class.metaclass
    delegate type_vars, instance_type
    delegate :abstract?, instance_type
    delegate generic_nest, instance_type

    def metaclass?
      true
    end

    def class_var_owner
      instance_type
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      instance_type.to_s(io)
      io << ":Class"
    end
  end

  module MultiType
    def concrete_types
      types = [] of Type
      each_concrete_type { |type| types << type }
      types
    end
  end

  # Base class for union types.
  abstract class UnionType < Type
    include MultiType

    getter program : Program
    getter union_types : Array(Type)

    def initialize(@program, @union_types)
    end

    def parents
      nil
    end

    def generic_nest
      @union_types.max_of &.generic_nest
    end

    def includes_type?(other_type)
      union_types.any? &.includes_type?(other_type)
    end

    def covariant?(other_type)
      union_types.all? &.covariant? other_type
    end

    def filter_by_responds_to(name)
      apply_filter &.filter_by_responds_to(name)
    end

    def apply_filter
      filtered_types = @union_types.compact_map do |union_type|
        yield union_type
      end

      case filtered_types.size
      when 0
        nil
      when 1
        filtered_types.first
      else
        program.type_merge_union_of(filtered_types)
      end
    end

    def has_def?(name)
      union_types.any? &.has_def?(name)
    end

    def has_def_without_parents?(name)
      union_types.any? &.has_def_without_parents?(name)
    end

    def each_concrete_type
      union_types.each do |type|
        if type.is_a?(VirtualType)
          type.subtypes.each do |subtype|
            yield subtype
          end
        else
          yield type
        end
      end
    end

    def virtual_type
      if union_types.any? { |t| t.virtual_type != t }
        program.type_merge(union_types.map(&.virtual_type)).not_nil!
      else
        self
      end
    end

    def expand_union_types
      if union_types.any?(&.is_a?(NonGenericModuleType))
        types = [] of Type
        union_types.each &.append_to_expand_union_types(types)
        types
      else
        union_types
      end
    end

    def implements?(other_type : Type)
      other_type = other_type.remove_alias
      self == other_type || union_types.all?(&.implements?(other_type))
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      # Use T? if this is a nilable type with just two types inside it
      if @union_types.size == 2 && @union_types.last.is_a?(NilType)
        io << @union_types.first
        io << "?"
        return
      end

      io << "(" unless skip_union_parens
      names = @union_types.join(" | ", io)
      io << ")" unless skip_union_parens
    end

    def type_desc
      "union"
    end
  end

  # A union type that has two types: Nil and another Reference type.
  # Can be represented as a maybe-null pointer where the type id
  # of the type that is not nil is known at compile time.
  class NilableType < UnionType
    def initialize(@program, not_nil_type)
      super(@program, [@program.nil, not_nil_type] of Type)
    end

    def not_nil_type
      @union_types.last
    end

    def reference_like?
      true
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      not_nil_type.to_s(io)
      io << "?"
    end
  end

  # A union type that has Nil and other reference-like types.
  # Can be represented as a maybe-null pointer but the type id is
  # not known at compile time.
  class NilableReferenceUnionType < UnionType
    def reference_like?
      true
    end
  end

  # A union type that doesn't have nil, and all types are reference-like.
  # Can be represented as a never-null pointer.
  class ReferenceUnionType < UnionType
    def reference_like?
      true
    end
  end

  # A union type of nil and a single function type.
  class NilableFunType < UnionType
    def initialize(@program, fun_type)
      super(@program, [@program.nil, fun_type] of Type)
    end

    def primitive_like?
      true
    end

    def fun_type
      @union_types.last.remove_typedef as FunInstanceType
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      io << "("
      @union_types.last.to_s(io)
      io << ")"
      io << "?"
    end
  end

  # A union type of nil and a single pointer type.
  class NilablePointerType < UnionType
    def initialize(@program, pointer_type)
      super(@program, [@program.nil, pointer_type] of Type)
    end

    def primitive_like?
      true
    end

    def pointer_type
      @union_types.last.remove_typedef as PointerInstanceType
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      @union_types.last.to_s(io)
      io << "?"
    end
  end

  # A union type that doesn't match any of the previous definitions,
  # so it can contain Nil with primitive types, or Reference types with
  # primitives types.
  # Must be represented as a union.
  class MixedUnionType < UnionType
    def passed_by_value?
      true
    end
  end

  class Const < NamedType
    property value : ASTNode
    getter scope_types : Array(Type)
    getter scope : Type?
    property vars : MetaVars?
    property used : Bool
    property? visited : Bool
    property? initialized : Bool
    property visitor : BaseTypeVisitor?

    def initialize(program, container, name, @value, @scope_types = [] of Type, @scope = nil)
      super(program, container, name)
      @used = false
      @visited = false
      @initialized = false
    end

    def type_desc
      "constant"
    end
  end

  module VirtualTypeLookup
    record Change, type : Type, def : Def

    def virtual_lookup(type)
      type
    end

    def filter_by_responds_to(name)
      filtered = virtual_lookup(base_type).filter_by_responds_to(name)
      return filtered.virtual_type if filtered

      result = [] of Type
      collect_filtered_by_responds_to(name, base_type, result)
      program.type_merge_union_of(result)
    end

    def collect_filtered_by_responds_to(name, type, result)
      type.subclasses.each do |subclass|
        unless subclass.is_a?(GenericClassType)
          filtered = virtual_lookup(subclass).filter_by_responds_to(name)
          if filtered
            result << virtual_lookup(subclass).virtual_type
            next
          end
        end

        collect_filtered_by_responds_to(name, subclass, result)
      end
    end
  end

  class VirtualType < Type
    include MultiType
    include DefInstanceContainer
    include VirtualTypeLookup
    include InstanceVarContainer

    getter program : Program
    getter base_type : NonGenericClassType

    def initialize(@program, @base_type)
    end

    delegate leaf?, base_type
    delegate superclass, base_type
    delegate lookup_first_def, base_type
    delegate lookup_defs, base_type
    delegate lookup_defs_with_modules, base_type
    delegate lookup_instance_var, base_type
    delegate lookup_instance_var?, base_type
    delegate index_of_instance_var, base_type
    delegate lookup_macro, base_type
    delegate lookup_macros, base_type
    delegate has_instance_var_in_initialize?, base_type
    delegate all_instance_vars, base_type
    delegate owned_instance_vars, base_type
    delegate :abstract?, base_type
    delegate allocated?, base_type
    delegate :"allocated=", base_type
    delegate is_subclass_of?, base_type
    delegate implements?, base_type
    delegate covariant?, base_type
    delegate ancestors, base_type

    def has_instance_var_in_initialize?(name)
      if base_type.abstract?
        each_concrete_type do |subtype|
          unless subtype.has_instance_var_in_initialize?(name)
            return false
          end
        end
        true
      else
        base_type.has_instance_var_in_initialize?(name)
      end
    end

    def metaclass
      @metaclass ||= VirtualMetaclassType.new(program, self)
    end

    def reference_like?
      true
    end

    def each_concrete_type
      subtypes.each do |subtype|
        yield subtype unless subtype.abstract?
      end
    end

    def subtypes
      subtypes = [] of Type
      collect_subtypes(base_type, subtypes)
      subtypes
    end

    def subtypes(type)
      subtypes = [] of Type
      type.subclasses.each do |subclass|
        collect_subtypes subclass, subtypes
      end
      subtypes
    end

    def collect_subtypes(type, subtypes)
      unless type.is_a?(GenericClassType)
        subtypes << type
      end
      type.subclasses.each do |subclass|
        collect_subtypes subclass, subtypes
      end
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      base_type.to_s(io)
      io << "+"
    end

    def name
      to_s
    end
  end

  class VirtualMetaclassType < Type
    include DefInstanceContainer
    include VirtualTypeLookup

    getter program : Program
    getter instance_type : VirtualType

    def initialize(@program, instance_type)
      @instance_type = instance_type
    end

    @parents : Array(Type)?

    def parents
      @parents ||= [instance_type.superclass.try(&.metaclass) || @program.class_type] of Type
    end

    def leaf?
      instance_type.leaf?
    end

    delegate base_type, instance_type
    delegate cover, instance_type
    delegate lookup_first_def, instance_type

    def virtual_lookup(type)
      type.metaclass
    end

    def lookup_macro(name, args_size, named_args)
      nil
    end

    def lookup_macros(name)
      nil
    end

    def metaclass?
      true
    end

    def each_concrete_type
      instance_type.subtypes.each do |type|
        yield type.metaclass
      end
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      instance_type.to_s(io)
      io << ":Class"
    end
  end

  class FunType < GenericClassType
    def initialize(program, container, name, superclass, type_vars, add_subclass = true)
      super
      @variadic = true
      @struct = true
    end

    def instantiate(type_vars)
      if (instance = generic_types[type_vars]?)
        return instance
      end

      types = type_vars.map do |type_var|
        unless type_var.is_a?(Type)
          type_var.raise "argument to Proc must be a type, not #{type_var}"
        end
        type_var
      end
      instance = FunInstanceType.new(program, types)
      generic_types[type_vars] = instance
      initialize_instance instance
      instance.after_initialize
      instance
    end

    def new_generic_instance(program, generic_type, type_vars)
      raise "Bug: FunType#new_generic_instance shouldn't be invoked"
    end

    def type_desc
      "function"
    end
  end

  class FunInstanceType < GenericClassInstanceType
    include DefContainer
    include DefInstanceContainer

    getter program : Program
    getter fun_types : Array(Type)

    def initialize(@program, @fun_types)
      var = Var.new("T", self)
      var.bind_to var
      super(program, program.proc, {"T" => var} of String => ASTNode)

      args = arg_types.map_with_index { |type, i| Arg.new("arg#{i}", type: type) }

      fun_call = Def.new("call", args, Primitive.new(:fun_call, return_type))
      fun_call.raises = true

      add_def fun_call
      add_def Def.new("arity", body: NumberLiteral.new(fun_types.size - 1))
    end

    def struct?
      true
    end

    def allocated?
      true
    end

    def arg_types
      fun_types[0..-2]
    end

    def return_type
      fun_types.last
    end

    @parents : Array(Type)?

    def parents
      @parents ||= [@program.proc] of Type
    end

    def primitive_like?
      fun_types.all? &.primitive_like?
    end

    def passed_by_value?
      false
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true)
      io << "("
      size = fun_types.size
      fun_types.each_with_index do |fun_type, i|
        if i == size - 1
          io << " -> "
        elsif i > 0
          io << ", "
        end
        fun_type.to_s(io)
      end
      io << ")"
    end
  end
end
