class Midian::RubyContext
  def initialize(interpreter)
    @interpreter = interpreter
  end

  def eval(script)
    instance_eval(script)
  end

  def track(track_name, track_number)
    @interpreter.root.context[:track_mappings][track_name] = track_number

    @interpreter.io.puts(
      JSON.dump({
        kind: 'track_mapping',
        name: track_name,
        number: track_number,
        time: @interpreter.root.context[:track_ts][@interpreter.root.context[:track_name]] || 0
      })
    )
  end

  def mark(name)
    @marks ||= {}
    @marks[name] = @interpreter.root.context[:track_ts][@interpreter.root.context[:track_name]]
  end

  def jump(name)
    @marks ||= {}
    raise %(There is no "#{name}" mark to jump to!) unless @marks[name]
    @interpreter.root.context[:track_ts][@interpreter.root.context[:track_name]] = @marks[name]
  end

  def sysex(bytes)
    # Even though sysex does not require a track, for the timing to work
    # properly, we need to associate it with a track for now.
    @interpreter.io.puts(
      JSON.dump({
        kind: 'sysex',
        track: track_name,
        bytes: bytes,
        time: @interpreter.root.context[:track_ts][@interpreter.root.context[:track_name]] || 0
      })
    )
  end
end
