class Midian::Interpreter
  attr_accessor \
    :io,
    :tree,
    :context,
    :parent,
    :root,
    :directive_context,
    :ruby_context

  NOTE_OFFSETS = {
    'c' => 0,
    'd' => 2,
    'e' => 4,
    'f' => 5,
    'g' => 7,
    'a' => 9,
    'b' => 11,
  }

  def initialize(io, tree, context, parent=nil, root=nil)
    @io = io
    @tree = tree
    @context = context
    @parent = parent
    @root = root || self
    if self == @root
      @directive_context = Midian::DirectiveContext.new(self)
      @ruby_context = Midian::RubyContext.new(self)
    end
  end

  # TODO: In the case of a closure, we want a fresh context which proxies the
  # parent context. This way, variables which are newly defined are thrown out
  # while parent variables may still be accessed.
  def interpret
    if @tree.respond_to?(:keys)
      @tree.each do |key, node|
        if node.is_a?(Parslet::Slice)
          visit(key, node, true)
        else
          visit(key, node, false)
          context = {}.merge(@context)
          interpreter = Midian::Interpreter.new(@io, node, context, self, @root)
          interpreter.interpret
        end
      end
    else
      @tree.each do |node|
        context = {}.merge(@context)
        interpreter = Midian::Interpreter.new(@io, node, context, self, @root)
        interpreter.interpret
      end
    end
  end

  def inspect
    io = StringIO.new
    io << %(#<#{self.class.name}:#{self.object_id})
    io << ' '
    io << %(@tree=#{@tree.inspect})
    io << ', '
    io << %(@context=#{@context.inspect})
    io << ', '
    parent_inspect = @parent.is_a?(self.class) ?
      %(#<#{@parent.class.name}:#{@parent.object_id}>) :
      @parent.inspect
    io << %(@parent=#{parent_inspect})
    io << '>'
    io.string
  end

  def setup
    @io.puts(
      JSON.dump({
        kind: 'ppqn',
        value: @root.context[:ppqn],
        time: 0
      })
    )
    @io.puts(
      JSON.dump({
        kind: 'tempo',
        value: @root.context[:tempo],
        time: 0
      })
    )
  end

  def shutdown
    @io.puts(
      JSON.dump({
        kind: 'track_count',
        value: @root.context[:track_mappings].length,
        time: 0
      })
    )
  end

  # Break each conditional into its own handler.
  def visit(key, node, is_slice)
    # We want to ignore these nodes, because they are either comments or are
    # child nodes of nodes we will actually handle.
    return if key == :comment
    return if key == :expression
    return if key == :note
    return if key == :rest
    return if key == :duration
    return if key == :division
    return if key == :dots
    return if key == :digits
    return if key == :number

    if key == :track_name
      track_name = node.to_s
      @root.context[:track_name] = track_name
      @root.context[:track_ts][track_name] ||= 0
      @root.context[:track_mappings][track_name] = \
        @root.context[:track_mappings][track_name] ||
        (@root.context[:track_mappings].values.sort.last || -1) + 1
      return
    end

    if key == :velocity
      @root.context[:velocity] = node[:number][:digits].to_i
      return
    end

    if key == :octave
      @root.context[:octave] = node[:number][:digits].to_i
      return
    end

    if key == :octave_up
      @root.context[:octave] -= 1
      return
    end

    if key == :octave_down
      @root.context[:octave] += 1
      return
    end

    if key == :length
      @root.context[:duration] = node_to_duration(node[:duration])
      return
    end

    if key == :tempo
      @root.context[:tempo] = node.values.first.to_i
      @io.puts(
        JSON.dump({
          kind: :tempo,
          value: @root.context[:tempo],
          time: @root.context[:track_ts][@root.context[:track_name]] || 0
        })
      )
      return
    end

    if key == :raw_note
      midi_note = node.values.first.to_i
      track_mapping = @root.context[:track_mappings][@root.context[:track_name]]
      duration = @root.context[:duration]
      ppqn = duration_to_ppqn(duration)
      t = @root.context[:track_ts][@root.context[:track_name]]
      @io.puts(
        JSON.dump({
          kind: :note_on,
          track: track_mapping,
          midi_note: midi_note,
          duration: ppqn,
          time: t
        })
      )
      @io.puts(
        JSON.dump({
          kind: :note_off,
          track: track_mapping,
          midi_note: midi_note,
          duration: 0,
          time: t + ppqn
        })
      )
    end

    if key == :run
      raise 'A track must be specified.' unless @root.context[:track_name]
      notes = nil
      duration = nil
      if node.last[:duration]
        notes = node[0..-2]
        duration = node_to_duration(node.last[:duration])
      end
      notes ||= node
      duration ||= @root.context[:duration]
      ppqn = duration_to_ppqn(duration)
      notes.each do |note|
        t = @root.context[:track_ts][@root.context[:track_name]]
        if note[:rest]
          @io.puts(
            JSON.dump({
              kind: :rest,
              track: track_mapping,
              duration: ppqn,
              time: t
            })
          )
        else
          note = note[:note].to_s
          octave = @root.context[:octave]
          midi_note = note_and_octave_to_midi_note(note, octave)
          track_mapping = @root.context[:track_mappings][@root.context[:track_name]]
          @io.puts(
            JSON.dump({
              kind: :note_on,
              track: track_mapping,
              midi_note: midi_note,
              velocity: @root.context[:velocity],
              duration: ppqn,
              time: t
            })
          )
          @io.puts(
            JSON.dump({
              kind: :note_off,
              track: track_mapping,
              midi_note: midi_note,
              velocity: @root.context[:velocity],
              duration: 0,
              time: t + ppqn
            })
          )
        end
        @root.context[:track_ts][@root.context[:track_name]] += ppqn
      end
      return
    end

    if key == :directive
      result = @root.directive_context.eval(node)
      # TODO: Should I do something with result?
      return
    end

    if key == :ruby
      result = @root.ruby_context.eval(node)
      # TODO: Should I do something with result?
      return
    end

    raise %("#{key}" is not supported.)
  end

  # Transforms a duration node into a duration.
  def node_to_duration(node)
    {
      division: node[:division].to_i,
      dots: node[:dots].length
    }
  end

  # Transforms a duration into ppqn.
  def duration_to_ppqn(duration)
    division = duration[:division]
    dots = duration[:dots]
    base = (4.0 / division) * @root.context[:ppqn]
    raise "Unsupported division: #{division}" unless division

    modifier = 0
    divisor = 0.5
    dots.times do |i|
      modifier += base * divisor
      divisor *= 0.5
    end

    base + modifier
  end

  def note_and_octave_to_midi_note(note, octave)
    octave_offset = octave * 12
    note_offset = NOTE_OFFSETS[note.match(/[a-g]/).to_s] +
      -(note.scan('-').length) +
      note.scan('+').length +
      note.scan('#').length
    octave_offset + note_offset
  end
end
