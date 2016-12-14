class Midian::DirectiveContext
  def initialize(interpreter)
    @interpreter = interpreter
  end

  def eval(script)
    components = script.to_s.strip.split(/\s+/)
    name = components.first.to_sym

    if name == :Track
      raise 'Invalid "Track" directive.' if components.length != 3
      raise 'Invalid "Track" directive.' unless components[2].match(/^\d+$/)
      track_name = components[1]
      track_number = components[2].to_i
      @interpreter.root.ruby_context.track(track_name, track_number)
      return
    end

    # If we don't find a matching directive, eval it as if it's Ruby.
    @interpreter.root.ruby_context.eval(script)
  end
end
