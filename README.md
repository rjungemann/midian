# Midian

A set of tools for parsing an extended dialect of MML and emitting MIDI. The
parts can be easily repurposed.

## Installation

Or install it yourself as:

```bash
gem install midian
```

Or, if you want to use it in your own library, add this line to your
application's Gemfile:

```ruby
gem 'midian'
```

And then execute:

```bash
bundle
```

## Usage

### Setup

Make sure you have the gem installed.

Make sure you have Homebrew installed.

```bash
brew install fluid-synth wget
wget -c http://thefifthcircuit.stuff.s3.amazonaws.com/arachno-soundfont-10-sf2.zip
unzip arachno-soundfont-10-sf2.zip
rm arachno-soundfont-*.zip
mv arachno-soundfont-* arachno-soundfont
```

### Basics

Put some MML in a file, like this:

```bash
# Put some MML in a file.
echo 'T a4bc8 a4b>g8<' > test.mml

# Use Midian to generate a MIDI file.
cat test.mml | midian > test.mid

# Test out the MIDI file using fluidsynth.
fluidsynth 'arachno-soundfont/Arachno SoundFont - Version 1.0.sf2' test.mid
```

You can also pipe MML directly into Midian.

```bash
echo 'T a4bc8 a4b>g8<' | midian > test.mid
```

You can inspect the MIDI hex output safely like so:

```bash
cat test.mml | midian | midian-hexdump
```

You can run the whole pipeline manually like so:

```bash
echo 'T abcd4' |
  midian-preprocessor |
  midian-parser |
  midian-organizer |
  midian-shoehorn
```

This allows for stages of the pipeline to be developed in isolation.

### Extended MML syntax

Whitespace is almost entirely insignificant. It can be omitted or added in
nearly any circumstance.

#### Basic MML

* `o4` - Set the current octave to `4`.
* `<` - Lower current octave by `1`.
* `>` - Raise current octave by `1`.
* `v80` - Set MIDI velocity to `80`.
* `d4` - Set default duration to `4` (quarter note).
* `n36` - Play MIDI note `36` (a C) with the default velocity and duration.
* `t120` - Change the song tempo to `120`.
* `a` - Play an A in the current octave.
* `a4` - Play an A as a quarter note.
* `ab4` - Play an A, then a B, as quarter notes.
* `a4bc8` - Play an A as a quarter note followed by a B and a C as eighth notes.
* `r4` - Rest for a quarter note.
* `T` - Switch to track `T`. Track names are all-uppercase alphanumeric words.
Delta times are tracked independently for each track.

Valid notes are `a`, `b`, `c`, `d`, `e`, `f`, `g`.

Valid durations are `32`, `24`, `16`, `12`, `9`, `8`, `6`, `4`, `3`, `2`, `1`.
Note that this allows for triplets. Durations may be appended with any number
of dots. Each dot will add half-again the duration to itself.

Lines beginning with `;` are comments.

Lines beginning with `#` are directives. The only directive that is handled
right now is `#Track`, which allows for mapping of tracks to a MIDI channel
(see below).

#### Directives

```
#Track T 1
```

Map the track named `T` to MIDI channel `1`.

More directives will come shortly. See `midian/lib/midian/directive_context.rb`.

#### Preprocessor directives (macros)

```
{{code}}
```

Code is evaluated as Ruby, and if it returns a value, the value will be printed
into the resulting code. You can use this to create loops:

```
{{4.times do}}a4bc8{{end}}
```

More directives will come shortly. See `midian/lib/midian/preprocessor.rb`.

#### Inline Ruby code

```
[[code]]
```

Inline Ruby code. Code is evaluated at evaluation time, and this can be used to
add new functionality to the interpreter. For example:

`[[mark :foo]]` - Store current MIDI delta time in a mark named `:foo`.

`[[jump :foo]]` - Rewind MIDI delta time to the point in time marked `:foo`.

`[[sysex '10421240007F0041']]` - Send sysex hex string as hex bytes. It will
automatically be prepended with `f0` and the length, and appended with `f7`.


More directives will come shortly. See `midian/lib/midian/ruby_context.rb`.

#### TODO

MML features:

* Ties (`&`)
* Chords using `(` and `)`
* `!` variables
* `@` variables
* Loops using `[` and `]`
* Setting of MIDI track names
* More raw MIDI Ruby directives
* Ignored `|` for readability
* Loops using `|:` and `:|`

Other:

* Start adding tests
* Document the various stages

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/[USERNAME]/midian. This project is intended to be a safe,
welcoming space for collaboration, and contributors are expected to adhere to
the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT
License](http://opensource.org/licenses/MIT).
