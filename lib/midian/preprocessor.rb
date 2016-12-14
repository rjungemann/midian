class Midian::Preprocessor::Context
  def initialize
  end

  # TODO: Put methods here.
end

class Midian::Preprocessor::Parser < Parslet::Parser
  rule(:whitespace) { match["\t\n "] }
  rule(:whitespaces?) { whitespace.repeat }

  rule(:left_brackets) { str('{{') }
  rule(:right_brackets) { str('}}') }
  rule(:not_left_brackets) { (left_brackets.absent? >> any).repeat(1) }
  rule(:not_brackets) {
    ((left_brackets | right_brackets).absent? >> any).repeat
  }

  rule(:template) {
    left_brackets >>
      whitespaces? >>
      not_brackets.maybe.as(:expression) >>
      whitespaces? >>
      right_brackets
  }

  rule(:templates) {
    (not_left_brackets.as(:code) | template).repeat
  }

  root(:templates)
end

class Midian::Preprocessor::Interpreter
  attr_reader :tree, :rendered

  def initialize(tree)
    @tree = tree
    @rendered = nil
  end

  def render
    io = StringIO.new
    io << '_buf = StringIO.new'
    io << "\n"
    @tree.each do |node|
      key = node.keys.first
      value = node.values.first
      if key == :code
        io << "_buf << %(#{value})"
        io << "\n"
      elsif key == :expression
        io << 'value = ('
        io << value
        io << ')'
        io << "\n"
        io << 'value and _buf << value'
        io << "\n"
      else
        raise "Invalid node #{node.inspect}"
      end
    end
    io << '_buf.string'
    @rendered = io.string
    self
  end

  def result(binding=nil)
    raise 'You must call #render first!' unless @rendered
    return eval(@rendered) unless binding
    return binding.instance_eval(@rendered) unless binding.respond_to?(:eval)
    binding.eval(@rendered)
  end
end
