class Midian::Generator
  def initialize(io)
    @io = io
  end

  def generate(&block)
    self.instance_exec(&block)
  end

  def header(&block)
    @io << Midian::Generator::Header.new.generate(&block).string
  end

  def track(&block)
    @io << Midian::Generator::Track.new.generate(&block).string
  end
end

module Midian::Generator::Helpers
  def string_to_hex(s)
    s.unpack('H*').first
  end

  def int_to_hex(n, nibbles, max_value=nil)
    max_value ||= ('f' * nibbles).to_i(16)
    raise "#{n} cannot be greater than #{max_value}." if n > max_value
    n.to_s(16).rjust(nibbles, '0')
  end

  def write_hex_bytes(f, hex)
    f.write([hex].pack('H*'))
  end

  def ascii_to_hex(s)
    s
      .encode(Encoding.find('ASCII'), {
        invalid: :replace,
        undef: :replace,
        replace: '?'
      })
      .unpack('U*')
      .map { |n| n.to_s(16) }
      .join('')
  end

  def variable_length_hex(val)
    buffer = []
    buffer << (val & 0x7f)
    val = (val >> 7)
    while val > 0
      buffer << (0x80 + (val & 0x7f))
      val = (val >> 7)
    end
    buffer
      .reverse!
      .map { |n| n.to_s(16).rjust(2, '0') }
      .join
  end
end

class Midian::Generator::Header
  include Midian::Generator::Helpers

  def initialize
    @io = StringIO.new
  end

  def generate(&block)
    instance_exec(&block) if block
    header_data = @io.string

    # Reset the instance `@io`.
    @io = StringIO.new

    io = StringIO.new
    write_hex_bytes(io, header_marker)
    write_hex_bytes(io, header_length(header_data))
    write_hex_bytes(io, header_data)
    io
  end

  # Helpers

  def header_marker
    string_to_hex('MThd')
  end

  def header_length(header_data)
    int_to_hex((header_data.length * 0.5).floor, 8)
  end

  # IO Helpers

  def set_general_midi_version(v)
    @io << int_to_hex(v, 4)
  end

  def set_track_count(n)
    @io << int_to_hex(n, 4)
  end

  def set_ppqn(n)
    @io << int_to_hex(n, 4, 32768)
  end
end

class Midian::Generator::Track
  include Midian::Generator::Helpers

  def initialize
    @io = StringIO.new
  end

  def generate(&block)
    instance_exec(&block) if block
    track_data = @io.string

    # Reset the instance `@io`.
    @io = StringIO.new

    io = StringIO.new
    write_hex_bytes(io, track_marker)
    write_hex_bytes(io, track_length(track_data))
    write_hex_bytes(io, track_data)
    io
  end

  # Helpers

  def track_marker
    string_to_hex('MTrk')
  end

  def track_length(track_data)
    int_to_hex((track_data.length * 0.5).floor, 8)
  end

  # IO Helpers

  def sysex_message(t, hex_string)
    length = (hex_string.length * 0.5).floor + 2
    @io << variable_length_hex(t) + 'f0' + int_to_hex(length, 2) + hex_string + 'f7'
  end

  def enable_general_midi(t)
    @io << sysex_message(t, '7e7f0901')
  end

  def set_tempo(t, bpm)
    bpm_to_us = 60_000_000 / bpm
    @io << variable_length_hex(t) + 'ff5103' + int_to_hex(bpm_to_us, 6)
  end

  def set_omni(t)
    @io << variable_length_hex(t) + 'b07d00'
  end

  def set_poly(t)
    @io << variable_length_hex(t) + 'b07f00'
  end

  def set_track_name(t, s)
    bytes = ascii_to_hex(s)
    @io << variable_length_hex(t) +
      'ff03' +
      int_to_hex((bytes.length * 0.5).floor, 2) +
      bytes
  end

  def program_change(t, channel_number, n)
    @io << variable_length_hex(t) +
      'c' +
      int_to_hex(channel_number, 1) +
      int_to_hex(n, 2)
  end

  def note_on(t, channel_number, note, velocity)
    @io << variable_length_hex(t) +
      '9' +
      int_to_hex(channel_number, 1) +
      int_to_hex(note, 2) +
      int_to_hex(velocity, 2)
  end

  def note_off(t, channel_number, note, velocity)
    @io << variable_length_hex(t) +
      '8' +
      int_to_hex(channel_number, 1) +
      int_to_hex(note, 2) +
      int_to_hex(velocity, 2)
  end

  def end_of_track(t)
    @io << variable_length_hex(t) + 'ff2f00'
  end
end
