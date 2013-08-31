class LLVM::GenericValue
  def to_string
    (to_ptr.read_pointer + 4).read_string
  end

  def to_f64
    to_f(LLVM::Double)
  end
end
