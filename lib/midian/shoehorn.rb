class Midian::Shoehorn
  def initialize(io)
    @io = io
    @track_count = nil
    @ppqn = nil
    @tempo = nil
    @track_mappings = {}

    # Current track data
    @track_number = nil
  end

  def shoehorn
    io = StringIO.new
    generator = Midian::Generator.new(io)
    header = Midian::Generator::Header.new

    loop do
      line = @io.gets
      break if line.nil?
      break if line == "\n"
      data = JSON.load(line)
      visit_header(header, data)
    end
    header.set_general_midi_version(1)
    header.set_track_count(@track_count)
    header.set_ppqn(@ppqn)
    io << header.generate.string

    global_track = Midian::Generator::Track.new
    global_track.enable_general_midi(0)
    global_track.set_tempo(0, @tempo)
    global_track.set_omni(0)
    global_track.set_poly(0)
    global_track.end_of_track(0)
    io << global_track.generate.string

    # TODO: Use track count for looping instead.
    current_track = Midian::Generator::Track.new
    loop do
      line = @io.gets
      if line.nil?
        break
      end
      if line == "\n"
        io << current_track.generate.string if current_track
        current_track = Midian::Generator::Track.new
        next
      end
      data = JSON.load(line)
      visit_track(current_track, data)
    end
    io << current_track.generate.string if current_track
    io
  end

  def visit_header(header, data)
    if data['kind'] == 'track_count'
      @track_count = data['value'] + 1
      return
    end

    if data['kind'] == 'ppqn'
      @ppqn = data['value']
      return
    end

    if data['kind'] == 'tempo'
      @tempo = data['value']
      return
    end

    if data['kind'] == 'track_mapping'
      @track_mappings[data['number'] + 1] = data['name']
      return
    end

    raise "Unidentified header message #{data.inspect}"
  end

  def visit_track(track, data)
    if data['kind'] == 'track'
      track_number = data['value'] + 1
      track_name = @track_mappings[track_number]

      track.set_track_name(0, track_name) if track_name

      return
    end

    if data['kind'] == 'note_on'
      delta_time = data['delta_time'].floor
      track_number = data['track']
      midi_note = data['midi_note']
      velocity = data['velocity']

      track.note_on(delta_time, track_number, midi_note, velocity)

      return
    end

    if data['kind'] == 'note_off'
      delta_time = data['delta_time'].floor
      track_number = data['track']
      midi_note = data['midi_note']
      velocity = data['velocity']

      track.note_off(delta_time, track_number, midi_note, velocity)

      return
    end

    raise "Unidentified track message #{data.inspect}"
  end
end
