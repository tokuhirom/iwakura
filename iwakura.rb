require 'rubygems'
require 'treetop'
require "strscan"

Treetop.load 'iwakura_grammar'

class Iwakura
  module Parser
    class TT
      def initialize
        @mode = :normal
      end

      def scan(src)
        s = StringScanner.new(src)

        result = []

        while !s.eos?
          case @mode
          when :expression
            case
            when s.scan(/\s+/)
              # nothing
            when s.scan(/%\]/)
              result.push([:TOKEN_REXP])
              @mode = :normal
            when s.scan(/([1-9][0-9]*)/)
              # expression
              result.push([:TOKEN_INT, s[1]])
            when s.scan(/\+/)
              # expression
              result.push([:TOKEN_PLUS])
            else
              throw "Unknown expression: #{s}"
            end
          when :normal
            case
            when s.scan(/\[\%/)
              result.push([:TOKEN_LEXP])
              @mode = :expression
            when s.scan(/([^\[]+)/)
              result.push([:TOKEN_STRING, s[1]])
            end
          end
        end

        return result
      end

      def parse(src)
        tokens = scan(src)
        p tokens
        @idx = 0
        @tokens = tokens
        return _parse()
      end

      def _parse
        ast = []

        while next_token
          case
          when ji = _parse_ji()
            ast.push(ji)
          when exp = _parse_exp_part()
            ast.push(exp)
          else
            raise "Unexpected. #{next_token}"
          end
        end
        Node.new(:NODE_ROOT, ast)
      end

      def _parse_ji
        case next_token
        when :TOKEN_STRING
          Node.new(:NODE_JI, use_token[1])
        else
          nil
        end
      end

      def _parse_exp_part
        case next_token
        when :TOKEN_LEXP
          use_token

          case
          when exp = _parse_additive_exp()
            case
            when :TOKEN_REXP
              use_token
              return Node.new(:NODE_EXP, exp)
            else
              raise "Missing %] after [%"
            end
          else
            raise "Missing exp after [%"
          end
        else
          nil
        end
      end

      def _parse_additive_exp
        case
        when n = _parse_primary()
          case next_token
          when :TOKEN_PLUS
            use_token
            case
            when m = _parse_primary()
              return Node.new(:NODE_PLUS, [n, m])
            else
              raise "Unexpected #{next_token} when expected primary"
            end
          else
            return n
          end
        else
          nil
        end
      end

      def next_token
        if @tokens.size > @idx+1
          @tokens[@idx+1][0]
        else
          nil
        end
      end

      def use_token
        @idx += 1
        @tokens[@idx]
      end

      def _parse_primary
        case next_token
        when :TOKEN_INT
          Node.new(:NODE_INT, use_token[1])
        else
          nil
        end
      end

      def primary(tokens)
        primary[0]
      end
    end

    class Node
      def initialize(type, info)
        @type = type
        @info = info
      end
    end
  end

  class CodeGen
    def generate(node)
      node[0]
    end
  end

  class VM
    def initialize
      @pc = 0
    end

    def run
    end
  end

  def initialize(parser=Parser::TT, path=['.'])
    @parser = parser.new()
    @path = path
  end

  def render(path, args={})
    @path.each do |dir|
      if File.exists?(File.join(dir, path))
        src = File.read(File.join(dir, path))
        return @parser.parse(src)
      end
    end

    raise "Template file Not Found #{path} in (#{@path.join(",")})"
  end
end

tmpl = Iwakura.new()
p tmpl.render('foo.tt', {})

__END__

TODO: cache


XXX: [% 3+5 %]
concat:
  - string: "XXX: "
- string: "XXX: "

# vim: filetype=ruby expandtab tabstop=2 shiftwidth=2 autoindent smartindent
