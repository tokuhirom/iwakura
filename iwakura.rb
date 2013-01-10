require 'rubygems'
require "strscan"

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
            when s.scan(/\-/)
              result.push([:TOKEN_MINUS])
            else
              throw "Unknown token in expression: #{s.inspect}"
            end
          when :normal
            case
            when s.scan(/\[\%/)
              result.push([:TOKEN_LEXP])
              @mode = :expression
            when s.scan(/([^\[]+)/)
              result.push([:TOKEN_JI, s[1]])
            end
          end
        end

        return result
      end

      def parse(src)
        tokens = scan(src)
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
            raise "Unexpected token in top level. #{next_token}"
          end
        end
        Node.new(:NODE_ROOT, ast)
      end

      def _parse_ji
        case next_token
        when :TOKEN_JI
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
          when :TOKEN_MINUS
            use_token
            case
            when m = _parse_primary()
              return Node.new(:NODE_MINUS, [n, m])
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
        if @tokens.size > @idx
          @tokens[@idx][0]
        else
          nil
        end
      end

      def use_token
        token = @tokens[@idx]
        @idx += 1
        return token
      end

      def _parse_primary
        case next_token
        when :TOKEN_INT
          Node.new(:NODE_INT, use_token[1].to_i)
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

      attr_accessor :type, :info
    end
  end

  OP_PRINT_RAW = 1
  OP_PLUS      = 2
  OP_INT       = 3
  OP_PRINT_TOP = 4
  OP_STOP      = 5
  OP_MINUS     = 6

  class CodeGen
    def initialize
      @iseq = []
    end

    def generate(node)
      case node.type
      when :NODE_ROOT
        node.info.each do |e|
          generate(e)
        end
        @iseq.push([OP_STOP])
      when :NODE_JI
        @iseq.push([OP_PRINT_RAW, node.info])
      when :NODE_EXP
        generate(node.info)
        @iseq.push([OP_PRINT_TOP])
      when :NODE_INT
        @iseq.push([OP_INT, node.info])
      when :NODE_PLUS
        generate(node.info[0])
        generate(node.info[1])
        @iseq.push([OP_PLUS])
      when :NODE_MINUS
        generate(node.info[1])
        generate(node.info[0])
        @iseq.push([OP_MINUS])
      else
        raise "Unknown node: #{node.type}"
      end
    end

    attr_accessor :iseq
  end

  class DisAssembler
    def self.disasm(iseq)
      result = []
      iseq.each do |x|
        case x[0]
        when OP_PRINT_RAW
          result.push "PRINT_RAW #{x[1]}"
        when OP_PLUS     
          result.push "PLUS"
        when OP_INT      
          result.push "INT"
        when OP_PRINT_TOP
          result.push "PRINT_TOP"
        when OP_STOP     
          result.push "STOP"
        end
      end
      return result
    end
  end

  class VM
    def initialize(iseq)
      @pc = 0
      @iseq = iseq
      @result = ''
      @stack = []
    end

    def run
      while true
        case @iseq[@pc][0]
        when OP_STOP
          return
        when OP_INT
          @stack.push(@iseq[@pc][1])
        when OP_PLUS
          @stack.push(@stack.pop() + @stack.pop())
        when OP_MINUS
          @stack.push(@stack.pop() - @stack.pop())
        when OP_PRINT_RAW
          @result += @iseq[@pc][1]
        when OP_PRINT_TOP
          @result += @stack.pop().to_s
        else
          raise "Unknown OP: #{@iseq[@pc]}"
        end

        @pc = @pc + 1
      end
    end

    attr_accessor :result
  end

  def initialize(parser=Parser::TT, path=['.'])
    @parser = parser.new()
    @path = path
  end

  def render(path, args={})
    @path.each do |dir|
      if File.exists?(File.join(dir, path))
        src = File.read(File.join(dir, path))
        ast = @parser.parse(src)
        generator = CodeGen.new()
        generator.generate(ast)
        iseq = generator.iseq
        # p DisAssembler.disasm(iseq)
        # p iseq
        vm = VM.new(iseq)
        vm.run
        return vm.result
      end
    end

    raise "Template file Not Found #{path} in (#{@path.join(",")})"
  end

  def render_string(src, args={})
      ast = @parser.parse(src)
      generator = CodeGen.new()
      generator.generate(ast)
      iseq = generator.iseq
      # p DisAssembler.disasm(iseq)
      # p iseq
      vm = VM.new(iseq)
      vm.run
      return vm.result
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
