class Midian::Parser < Parslet::Parser
  rule(:newline) { str("\n") }
  rule(:whitespace) { match["\t\n "] }
  rule(:whitespaces?) { whitespace.repeat }

  rule(:negative) { str('-').as(:negative) }
  rule(:digits) { match['0-9'].repeat.as(:digits) }
  rule(:number) { (negative.maybe >> digits).as(:number) }

  rule(:raw_note) { whitespaces? >> (str('n') >> number).as(:raw_note) }

  rule(:note) {
    whitespaces? >>
      ( match['a-g'] >> (str('+') | str('-') | str('#')).repeat ).as(:note)
  }
  rule(:rest) { whitespaces? >> (str('p') | str('r')).as(:rest) }

  rule(:octave_down) { whitespaces? >> str('<').as(:octave_down) }
  rule(:octave_up) { whitespaces? >> str('>').as(:octave_up) }
  rule(:octave) { whitespaces? >> (str('o') >> number).as(:octave) }

  rule(:velocity) { whitespaces? >> (str('v') >> number).as(:octave) }

  rule(:division) {
    (
      str('32') |
        str('24') |
        str('16') |
        str('12') |
        str('9') |
        str('8') |
        str('6') |
        str('4') |
        str('3') |
        str('2') |
        str('1')
    ).as(:division)
  }
  rule(:dots) {
    str('.').repeat.as(:dots)
  }
  rule(:duration) {
    whitespaces? >> (division >> dots).as(:duration)
  }

  rule(:length) { whitespaces? >> (str('l') >> duration).as(:length) }

  rule(:tempo) { whitespaces? >> (str('t') >> digits).as(:tempo) }

  # Runs are sets of notes with a duration.
  rule(:run) {
    (
      (note | rest).repeat(1) >> whitespaces? >> duration.maybe >> whitespaces?
    ).as(:run)
  }

  rule(:variable_expression) {
    str('@') >> match['a-z'].as(:variable_name)
  }

  rule(:expression) {
    (
      (
        (
          track_name |
            tempo |
            length |
            velocity |
            raw_note |
            octave |
            octave_down |
            octave_up |
            run |
            variable_declaration |
            variable_expression |
            loop_expression |
            ruby
        ) >>
          whitespaces?
      ).repeat(1)
    ).as(:expression)
  }

  rule(:loop_expression) {
    ruby.absent? >>
      whitespaces? >>
      str('[') >>
      expression.maybe.as(:loop) >>
      str(']') >>
      whitespaces? >>
      digits.maybe.as(:count) >>
      whitespaces?
  }

  rule(:comment) {
    whitespaces? >>
      str(';') >> (newline.absent? >> any).repeat.as(:comment) >>
      whitespaces?
  }

  rule(:directive) {
    whitespaces? >>
      str('#') >> (newline.absent? >> any).repeat.as(:directive) >>
      whitespaces?
  }

  rule(:track_name) {
    match['A-Z'].repeat(1).as(:track_name)
  }

  rule(:block) {
    whitespaces? >>
      str('{') >>
      whitespaces? >>
      (expression | loop_expression).repeat.as(:block) >>
      str('}') >>
      whitespaces?
  }

  rule(:variable_declaration) {
    whitespaces? >>
      str('@') >>
      match['a-z'].repeat(1).as(:variable_name) >>
      whitespaces? >>
      str('=') >>
      block
  }

  rule(:ruby) {
    whitespaces? >>
      str('[[') >> (str(']]').absent? >> any).repeat.as(:ruby) >>
      str(']]') >>
      whitespaces?
  }

  rule(:statement) {
    directive | comment | expression
  }

  rule(:statements) {
    statement.repeat(1)
  }

  root(:statements)
end
