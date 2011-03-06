require 'v8'
# JSLint bindings for ruby using v8.
#
# Usage:
#
#    require 'jslintrb-v8'
#    puts JSLint.new.check("var x = 5")
#
# will output:
#
#    Error at line 1 character 1: Missing "use strict" statement.
#      var x = 5
#    Error at line 1 character 10: Missing semicolon.
#      var x = 5
#
# Pass options into the constructor:
#
#   JSLint.new(:undef => false, :sub => true)
#
# Here is an example rake task:
#   require 'jslintrb-v8'
#   task :jslint do
#     jsl = JSLint.new(
#       :undef  => false,
#       :strict => false,
#       :nomen  => false,
#       :onevar => false,
#       :newcap => false
#     )
#     errors = []
#     path = File.join('javascripts', '**', '*.js')
#     Dir[path].each do |f|
#       e = jsl.check(File.read(f))
#       errors << "\nIn [#{f}]:\n#{e}\n" if e
#     end
#     if errors.empty?
#       puts "JSLinty-fresh!"
#     else
#       $stderr.write(errors.join("\n")+"\n");
#       raise "JSLint Errors Found"
#     end
#   end
#
class JSLint
  def initialize(opts = {})
    # default jslint settings
    @settings = {
      # by default, use JSLint as linter;
      # optionally, you can use JSHint
      # by passing 'jshint' instead
      #
      # for more information, see
      # http://jshint.com
      :linter     => 'jslint',

      # if ADsafe should be enforced
      :adsafe     => false,
      # if bitwise operators should not be allowed
      :bitwise    => true,
      # if the standard browser globals should be predefined
      :browser    => false,
      # if upper case HTML should be allowed
      :cap        => false,
      # if CSS workarounds should be tolerated
      :css        => false,
      # if debugger statements should be allowed
      :debug      => false,
      # if === should be required
      :eqeqeq     => true,
      # if eval should be allowed
      :evil       => false,
      # if for in statements must filter
      :forin      => false,
      # if HTML fragments should be allowed
      :fragment   => false,
      # if immediate invocations must be wrapped in parens
      :immed      => true,
      # if line breaks should not be checked
      :laxbreak   => false,
      # if constructor names must be capitalized
      :newcap     => true,
      # disallow initial or trailing underscores in names
      :nomen      => true,
      # if HTML event handlers should be allowed
      :on         => false,
      # if only one var statement per function should be allowed
      :onevar     => true,
      # if the scan should stop on first error
      :passfail   => false,
      # if increment/decrement should not be allowed
      :plusplus   => true,
      # if the . should not be allowed in regexp literals
      :regexp     => true,
      # if the Rhino environment globals should be predefined
      :rhino      => false,
      # if variables should be declared before used
      :undef      => true,
      # if use of some browser features should be restricted
      :safe       => false,
      # if the System object should be predefined
      :sidebar    => false,
      # require the "use strict"; pragma
      :strict     => true,
      # if all forms of subscript notation are tolerated
      :sub        => false,
      # if strict whitespace rules apply
      :white      => false,
      # if the Yahoo Widgets globals should be predefined
      :widget     => false
    }

    if @settings[:linter] == 'jshint'
      jshint_settings = {
        # tolerate automatic semicolon insertion
        :asi      => false,
        # allow the use of advanced (and potentially unsafe)
        # techniques like foo == null or assignments inside
        # structured elements such as if, for and while
        :boss     => false,
        # require curly braces around logical blocks
        :curly    => true,
        # allow logging functions that should be removed for production
        :devel    => false,
        # prohibit use of arguments.caller and arguments.callee
        :noarg    => true,
        # prohibit empty blocks
        :noempty  => true,
        # prohibit construction using "new"
        :nonew    => false
      }

      @settings.merge!(jshint_settings)
    end

    # override default settings with passed in options
    @settings.merge!(opts);

    @settings.keys.each do |setting|
      self.create_method(setting) { @settings[setting] }
      self.create_method("#{setting}=") { |x| @settings[setting] = x }
    end
  end

  def create_method(name, &block)
    self.class.send(:define_method, name, block)
  end

  def check(input)
    errors = []
    linter = self.linter.upcase

    V8::Context.new do |context|
      context.load(File.join(File.dirname(__FILE__), 'jslintrb-v8', self.linter.downcase + '.js'))

      # prep the context object
      @settings.each do |opt, val|
        context["JSLintRB#{opt}"]  = val
      end

      context['JSLintRBinput'] = lambda { input }

      context['JSLintRBerrors'] = lambda { |js_errors|
        js_errors.each do |e|
          errors << "Error at line #{e['line'].to_i + 1} " +
            "character #{e['character'].to_i + 1}: #{e['reason']}"
          errors << "  #{e['evidence']}"
        end
      }

      # do it
      context.eval [
        "#{linter}(JSLintRBinput(), {",
          @settings.keys.map { |k| "#{k} : JSLintRB#{k}" }.join(",\n"),
        "});",
        "JSLintRBerrors(#{linter}.errors);"
      ].join("\n")
    end

    if errors.empty?
      return nil
    else
      return errors.join("\n")
    end
  end
end
