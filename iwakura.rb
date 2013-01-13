require 'rubygems'
require "strscan"

class Iwakura
  module ParserBase
      # see http://en.wikipedia.org/wiki/Parsing_expression_grammar#Indirect_left_recursion
      def left_op(child, ops)
        case
        when lhs = self.send(child)
          retval = lhs

          loop do
            op = ops[next_token]
            break unless op

            use_token # op itself

            rhs = self.send(child)
            unless rhs
              raise "Unexpected #{next_token} when expected #{child}"
            end

            retval = Node.new(op, [retval, rhs])
          end

          return retval
        else
          nil
        end
      end
  end

  module Syntax
    class TT
      def self.scanner
        Scanner.new()
      end
      def self.parser
        Parser.new()
      end
      def parse(src)
        parser = Parser.new()
        tokens = scanner.scan(src)
        ast = parser.parse(tokens)
        return ast
      end

      class Parser
        include ParserBase

        def parse(tokens)
          @idx = 0
          @tokens = tokens
          return Node.new(:NODE_ROOT, _parse())
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
          Node.new(:NODE_LINES, ast)
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
            return _parse_if()
          else
            nil
          end
        end

        def _parse_body
          nodes = []

          end_ok = false

          while next_token
            case
            when ji = _parse_ji()
              nodes.push(ji)
              next
            when ed = _parse_end()
              end_ok = true
              break
            when exp = _parse_exp_part()
              nodes.push(exp)
              next
            else
              raise "Unexpected token in IF. #{next_token}"
            end
          end

          unless end_ok
            raise "Unexpected EOF in IF."
          end

          return nodes
        end

        def _parse_if
          case
          when next_token == :TOKEN_IF
            # [% IF exp %]body[% END %]
            use_token
            cond = _parse_additive_exp()

            if next_token == :TOKEN_REXP # %]
              use_token # %]
              nodes = _parse_body()
              return Node.new(:NODE_IF, [cond, nodes])
            end
          when next_token == :TOKEN_FOR
            # [% for ... in ... %]...[% end %]
            use_token

            raise "No ident after 'for' keyword. #{next_token}" unless next_token == :TOKEN_IDENT
            exp1 = use_token[1]

            raise "No 'in' keyword in 'for' keyword. #{next_token}" unless next_token == :TOKEN_IN
            use_token

            exp2 = _parse_additive_exp()
            raise "No expression after 'for' keyword(2). #{next_token }" unless exp2

            if next_token == :TOKEN_REXP # %]
              use_token # %]
              body = _parse_body()
              return Node.new(:NODE_FOR, [exp1, exp2, body])
            else
              raise "no %] after foo."
            end
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
        end

        def _parse_end
          orig_idx = @idx

          if next_token == :TOKEN_LEXP
            use_token
            if next_token == :TOKEN_END
              use_token
              if next_token == :TOKEN_REXP
                use_token
                return Node.new(:NODE_END)
              end
            end
          end

          @idx = orig_idx
          return nil
        end

        def _parse_additive_exp
          left_op(:_parse_term,
                  {:TOKEN_PLUS => :NODE_PLUS,
                  :TOKEN_MINUS => :NODE_MINUS})
        end

        def _parse_term
          left_op(:_parse_primary,
                  {:TOKEN_MUL => :NODE_MUL,
                  :TOKEN_DIV => :NODE_DIV})
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
            token = use_token
            Node.new(:NODE_INT, token[1].to_i)
          when :TOKEN_NIL
            use_token
            Node.new(:NODE_NIL)
          when :TOKEN_IDENT
            token = use_token
            return Node.new(:NODE_IDENT, token[1])
          when :TOKEN_LBRACKET
            use_token
            ary = []
            # []
            # [1,2,]
            # [1,2,3]

            while next_token
              val = _parse_primary
              if val.nil?
                if next_token == :TOKEN_RBRACKET
                  use_token
                  return Node.new(:NODE_ARRAY, ary)
                end
                raise "Unexpected value: #{next_token}"
              end
              ary.push(val)

              if next_token == :TOKEN_COMMA
                use_token
                next
              elsif next_token == :TOKEN_RBRACKET
                use_token
                return Node.new(:NODE_ARRAY, ary)
              else
                raise "Unexpected token: #{next_token}"
              end
            end
            raise "Unexpected EOF in array literal"
          else
            nil
          end
        end
      end

      class Scanner
        def initialize
        end

        def scan(src)
          @mode = :normal

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
              when s.scan(/if/)
                result.push([:TOKEN_IF])
              when s.scan(/for/)
                result.push([:TOKEN_FOR])
              when s.scan(/in/)
                result.push([:TOKEN_IN])
              when s.scan(/while/)
                result.push([:TOKEN_WHILE])
              when s.scan(/nil/)
                result.push([:TOKEN_NIL])
              when s.scan(/end/)
                result.push([:TOKEN_END])
              when s.scan(/([1-9][0-9]*)/)
                result.push([:TOKEN_INT, s[1]])
              when s.scan(/\[/)
                result.push([:TOKEN_LBRACKET])
              when s.scan(/\]/)
                result.push([:TOKEN_RBRACKET])
              when s.scan(/,/)
                result.push([:TOKEN_COMMA])
              when s.scan(/\*/)
                result.push([:TOKEN_MUL])
              when s.scan(/\+/)
                result.push([:TOKEN_PLUS])
              when s.scan(/\//)
                result.push([:TOKEN_DIV])
              when s.scan(/\-/)
                result.push([:TOKEN_MINUS])
              when s.scan(/([a-z][a-z0-9]*)/)
                result.push([:TOKEN_IDENT, s[1]])
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
      end
    end
  end

  class Node
    def initialize(type, info=nil)
      @type = type
      @info = info
    end

    attr_accessor :type, :info
  end

  OP_PRINT_RAW     =  1
  OP_PLUS          =  2
  OP_INT           =  3
  OP_PRINT_TOP     =  4
  OP_STOP          =  5
  OP_MINUS         =  6
  OP_MUL           =  7
  OP_DIV           =  8
  OP_NIL           =  9
  OP_JUMP_IF_FALSE = 10
  OP_ARRAY         = 11
  OP_BEGIN_FOR     = 12
  OP_CHECK_FOR     = 13
  OP_IDENT         = 14

  class CodeGen
    def initialize
      @iseq = []
    end

    def generate(node)
      case node.type
      when :NODE_ROOT
        generate(node.info)
        @iseq.push([OP_STOP])
      when :NODE_LINES
        node.info.each do |e|
          generate(e)
        end
      when :NODE_NIL
        @iseq.push([OP_NIL])
      when :NODE_JI
        @iseq.push([OP_PRINT_RAW, node.info])
      when :NODE_EXP
        generate(node.info)
        @iseq.push([OP_PRINT_TOP])
      when :NODE_INT
        @iseq.push([OP_INT, node.info])
      when :NODE_IDENT
        @iseq.push([OP_IDENT, node.info])
      when :NODE_DIV
        generate(node.info[1])
        generate(node.info[0])
        @iseq.push([OP_DIV])
      when :NODE_MUL
        generate(node.info[1])
        generate(node.info[0])
        @iseq.push([OP_MUL])
      when :NODE_PLUS
        generate(node.info[1])
        generate(node.info[0])
        @iseq.push([OP_PLUS])
      when :NODE_ARRAY
        node.info.reverse.each do |x|
          generate(x)
        end
        @iseq.push([OP_ARRAY, node.info.size])
      when :NODE_MINUS
        generate(node.info[1])
        generate(node.info[0])
        @iseq.push([OP_MINUS])
      when :NODE_FOR
        generate(node.info[1]) # e2
        jmp = [OP_BEGIN_FOR, [node.info[0]]]
        @iseq.push(jmp)
        begin_pt = @iseq.length
        node.info[2].each do |x|
          generate(x) # body
        end
        @iseq.push([OP_CHECK_FOR, begin_pt])
        jmp[1][1] = @iseq.length
      when :NODE_IF
        generate(node.info[0]) # expression
        jmp = [OP_JUMP_IF_FALSE]
        @iseq.push(jmp)
        node.info[1].each do |x|
          generate(x)
        end
        jmp[1] = @iseq.length
      else
        raise "Unknown node: #{node.type}"
      end
    end

    attr_accessor :iseq
  end

  class DisAssembler
    def self.disasm_one(x)
      case x[0]
      when OP_PRINT_RAW
        "PRINT_RAW #{x[1]}"
      when OP_NIL
        "NIL"
      when OP_PLUS     
        "PLUS"
      when OP_MUL     
        "MUL"
      when OP_DIV     
        "DIV"
      when OP_MINUS    
        "MINUS"
      when OP_INT      
        "INT #{x[1]}"
      when OP_PRINT_TOP
        "PRINT_TOP"
      when OP_STOP     
        "STOP"
      when OP_JUMP_IF_FALSE
        "JUMP_IF_FALSE"
      when OP_ARRAY
        "ARRAY: #{x[1]}"
      when OP_CHECK_FOR
        "CHECK_FOR: #{x[1]}"
      when OP_BEGIN_FOR
        "BEGIN_FOR: #{x[1]}"
      when OP_IDENT
        "IDENT: #{x[1]}"
      else
        "UNKNOWN: #{x[0]}"
      end
    end

    def self.disasm(iseq)
      result = []
      iseq.each do |x|
        result.push self.disasm_one(x)
      end
      return result
    end
  end

  class VM
    class Scope
      def initialize
        @data = Hash.new
      end

      def [](key)
        @data[key]
      end

      def []=(key, val)
        @data[key] = val
      end

      def has_key?(key)
        @data.has_key?(key)
      end
    end

    class ForScope < Scope
      def initialize(src, iter)
        @data = Hash.new
        @src = src
        @iter = iter
        @i = 0
      end

      def has_next?
        @i < @src.size
      end

      def next!
        @data[@iter] = @src[@i]
        @i = @i + 1
        return @data[@iter]
      end

      attr_accessor :src
      attr_accessor :iter
    end

    def initialize(iseq)
      @pc = 0
      @iseq = iseq
      @result = ''
      @stack = []
      @scope_stack  = [
        Scope.new()
      ]
    end

    def operand
      return @iseq[@pc][1]
    end

    def get_variable(name)
      @scope_stack.each do |v|
        return v[name] if v.has_key?(name)
      end
      return nil
    end

    def run
      while true
        puts "#{ @pc } #{DisAssembler.disasm_one(@iseq[@pc]) }"
        case @iseq[@pc][0]
        when OP_STOP
          return
        when OP_INT
          @stack.push(@iseq[@pc][1])
        when OP_MUL
          @stack.push(@stack.pop() * @stack.pop())
        when OP_DIV
          @stack.push(@stack.pop() / @stack.pop())
        when OP_PLUS
          @stack.push(@stack.pop() + @stack.pop())
        when OP_NIL
          @stack.push(nil)
        when OP_MINUS
          @stack.push(@stack.pop() - @stack.pop())
        when OP_PRINT_RAW
          @result += @iseq[@pc][1]
        when OP_PRINT_TOP
          @result += @stack.pop().to_s
        when OP_IDENT
          @stack.push(get_variable(operand))
        when OP_BEGIN_FOR
          scope = ForScope.new(@stack.pop(), operand[0])
          if scope.has_next?
            scope.next!
            @scope_stack.push(scope)
          else
            @pc = operand[1]
            next
          end
        when OP_CHECK_FOR
          scope = @scope_stack.last()
          if scope.has_next?
            scope.next!
            @pc = operand
            next
          else
            @scope_stack.pop()
          end
        when OP_ARRAY
          ary = []
          operand.times do
            ary.push(@stack.pop)
          end
          @stack.push(ary)
        when OP_JUMP_IF_FALSE
          unless @stack.pop
            @pc = @iseq[@pc][1]
            next
          end
        else
          raise "Unknown OP: #{@iseq[@pc]}"
        end

        @pc = @pc + 1
      end
    end

    attr_accessor :result
  end

  def initialize(syntax=Syntax::TT, path=['.'])
    @syntax = syntax
    @path   = path
  end

  def process(src, args={})
      tokens = @syntax.scanner.scan(src)
      if @dump_tokens
        p tokens
      end
      ast = @syntax.parser.parse(tokens)
      generator = CodeGen.new()
      generator.generate(ast)
      iseq = generator.iseq
      if @enable_disasm
        p DisAssembler.disasm(iseq)
      end
      vm = VM.new(iseq)
      vm.run
      return vm.result
  end

  def render(path, args={})
    @path.each do |dir|
      if File.exists?(File.join(dir, path))
        src = File.read(File.join(dir, path))
        return process(src, args)
      end
    end

    raise "Template file Not Found #{path} in (#{@path.join(",")})"
  end

  def render_string(src, args={})
    process(src, args)
  end

  attr_accessor :enable_disasm
  attr_accessor :dump_tokens
end

__END__

TODO: cache


XXX: [% 3+5 %]
concat:
  - string: "XXX: "
- string: "XXX: "

# vim: filetype=ruby expandtab tabstop=2 shiftwidth=2 autoindent smartindent
