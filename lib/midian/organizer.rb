class Midian::Organizer
  def initialize(io)
    @io = io
  end

  def organize
    io = StringIO.new
    groups = @io
      .read
      .split("\n")
      .map { |line| JSON.load(line) }
      .reject { |hash|
        hash['kind'] == 'rest' ||
          hash['kind'] == 'note_off'
      }
      .group_by { |hash| hash['track'] }
      .map { |key, group|
        t = 0
        [
          key,
          group
            .sort_by { |hash|
              hash['time']
            }
            .map { |hash|
              hash['delta_time'] = hash['time'] - t
              t = hash['time']
              hash
            }
        ]
      }

    groups.each.with_index { |(key, hashes), i|
      if key
        io.puts(
          JSON.dump({
            kind: :track,
            value: key,
            time: 0
          })
        )
      end
      hashes.each do |hash|
        if hash['kind'] == 'note_on'
          io.puts(JSON.dump(hash))
          io.puts(
            JSON.dump(
              hash.merge({
                'kind' => 'note_off',
                'time' => hash['time'] + hash['duration'],
                'duration' => 0,
                'delta_time' => hash['duration']
              })
            )
          )
        else
          io.puts(JSON.dump(hash))
        end
      end
      io.print("\n") if i < groups.length - 1
    }
    io
  end
end
