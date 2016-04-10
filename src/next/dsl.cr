module Spec2
  module DSL
    include Matchers
    extend Matchers

    module Spec2___
      include ::Spec2::DSL

      def __spec2_before_hook
      end

      def __spec2_after_hook
      end

      def __spec2_run_lets!
      end

      def __spec2_clear_lets
      end
    end

    SPEC2_CONTEXT = ::Spec2::DSL::Spec2___
    SPEC2_FULL_CONTEXT = ":root"

    macro fdescribe(what, file = __FILE__, line = __LINE__, &blk)
      ::Spec2::DSL.describe({{what}}, true, {{file}}, {{line}}) {{blk}}
    end

    macro describe(what, focused = false, file = __FILE__, line = __LINE__, &blk)
      {% if SPEC2_FULL_CONTEXT == ":root" %}
        ::Spec2::DSL.context(
      {% else %}
        context(
      {% end %}
        {{what}}, {{focused}}, {{file}}, {{line}}
      ) {{blk}}
    end

    macro fcontext(what, file = __FILE__, line = __LINE__, &blk)
      context({{what}}, true, {{file}}, {{line}}) {{blk}}
    end

    macro context(what, focused = false, file = __FILE__, line = __LINE__, &blk)
      {% name = what.id.stringify.gsub(/[^\w]/, "_") %}
      {% name = ("Spec2__" + name.camelcase).id %}

      {% full_name = "#{SPEC2_FULL_CONTEXT.id} -> #{what.id} (#{file.id}:#{line.id})" %}

      %current_context = @@__spec2_active_context
      module {{name.id}}
        include {{SPEC2_CONTEXT}}

        {% unless ::Spec2::Context::DEFINED[full_name] == true %}
          SPEC2_FULL_CONTEXT = {{full_name}}
          SPEC2_CONTEXT = {{name.id}}
          LETS = {} of String => Int32
          LETS_BANG = {} of String => Int32
          BEFORES = [] of Int32
          AFTERS = [] of Int32
          ITS = {} of String => Int32
          FITS = {} of String => Bool
          {% ::Spec2::Context::DEFINED[full_name] = true %}
        {% end %}

        __spec2_sanity_checks({{name}}, {{full_name}})

        @@__spec2_active_context = ::Spec2::Context
          .new(%current_context, {{what}}, {{focused}})

        (%current_context ||
         ::Spec2::Context.instance)
          .contexts << @@__spec2_active_context

        {{blk.body}}

        __spec2_def_lets
        __spec2_def_hooks
        __spec2_def_its
      end
    end

    macro __spec2_sanity_checks(name, full_name)
      {% if name.id.stringify != SPEC2_CONTEXT.id.stringify %}
        {% raise "Assertion failed: expected SPEC2_CONTEXT to equal #{name.id} but got #{SPEC2_CONTEXT}
         Full name: #{full_name.id}" %}
      {% end %}
    end

    macro it(what, focused = false, &blk)
      {% ITS[what] = blk %}
      {% FITS[what] = focused %}
    end

    macro fit(what, &blk)
      it({{what}}, true) {{blk}}
    end

    macro __spec2_def_its
      {% for what in ITS %}
        __spec2_def_it({{what}})
      {% end %}
    end

    macro __spec2_def_it(what)
      {% blk = ITS[what] %}
      {% focused = FITS[what] %}

      {% name = what.id.stringify.gsub(/[^\w]/, "_") %}
      {% name = ("Spec2__" + name.camelcase).id %}

      class {{name.id}} < ::Spec2::Example
        include {{SPEC2_CONTEXT}}

        def initialize(@context)
          @what = {{what}}
          @focused = {{focused}}
          @blk = -> {}
        end

        def run
          __spec2_delayed = [] of ->

          __spec2_before_hook
          __spec2_run_lets!
          {{blk.body}}

        ensure
          __spec2_after_hook
          __spec2_delayed.not_nil!.each &.call
        end
      end

      %current_context = (@@__spec2_active_context ||
                          ::Spec2::Context.instance)
      %current_context
        .examples << {{name.id}}.new(%current_context)
    end

    macro let(name, &blk)
      {% LETS[name] = blk %}
    end

    macro let!(name, &blk)
      {% LETS_BANG[name] = 1 %}
      let({{name}}) {{blk}}
    end

    macro __spec2_def_lets
      {% for what in LETS %}
        __spec2_def_let({{what}})
      {% end %}

      def __spec2_run_lets!
        super
        {% for what in LETS_BANG %}
          {{what.id}}
        {% end %}
      end

      def __spec2_clear_lets
        super
        {% for what in LETS %}
          @{{what.id}} = nil
        {% end %}
      end
    end

    macro __spec2_def_let(name)
      {% blk = LETS[name] %}

      def {{name.id}}
        @_{{name.id}} ||= {{name.id}}!
      end

      def {{name.id}}!
        {{blk.body}}
      end
    end

    macro subject(&blk)
      {% if blk.is_a?(Nop) %}
        __spec2_subject
      {% else %}
        let(__spec2_subject) {{blk}}
      {% end %}
    end

    macro subject(name, &blk)
      let({{name}}) {{blk}}
    end

    macro subject!(&blk)
      {% LETS_BANG["__spec2_subject".id] = 1 %}
      subject {{blk}}
    end

    macro subject!(name, &blk)
      let!({{name}}) {{blk}}
    end

    macro before(&blk)
      {% BEFORES << blk %}
    end

    macro after(&blk)
      {% AFTERS << blk %}
    end

    macro __spec2_def_hooks
      def __spec2_before_hook
        super
        {% for blk in BEFORES %}
          {{blk.body}}
        {% end %}
      end

      def __spec2_after_hook
        super
        {% for blk in AFTERS %}
          {{blk.body}}
        {% end %}
      end
    end

    macro delayed(&blk)
      __spec2_delayed << -> {{blk}}
    end

    def expect(actual)
      Expectation.new(actual)
    end

    def expect(&block)
      Expectation.new(block)
    end
  end
end
