module JavascriptRoutes

  FILENAME = File.join(Rails.root, 'public', 'javascripts', 'routes.js')
  FILENAME_PACKED = File.join(Rails.root, 'public', 'javascripts', 'routes-min.js')

  # Generate...
  #
  # Options are:
  #  :filename      => name of routes javascript file (default routes.js)
  #
  #  :routes       - which named routes (leave out for all)
  #
  #
  def self.generate(options = {})
    options.symbolize_keys!

    named_routes = options[:routes] || processable_named_routes2
    filename = options[:filename] || FILENAME

    # Create one function per route (simple lite version...)
    generate_routes(named_routes, filename)

  rescue => e
    puts("\n\nCould not write routes.js: \"#{e.class}:#{e.message}\"\n\n")
    File.truncate(filename, 0) rescue nil
  end

  def self.generate_routes(named_routes, filename)
    case Rails::VERSION::MAJOR
      when 3: generate_routes3(named_routes, filename)
      when 2: generate_routes2(named_routes, filename)
      else throw NotImplementedError.new("Unsupported Rails version")
    end
  end

  private

  def self.generate_routes2(named_routes, filename)
    route_functions = named_routes.map do |name, route|
      processable_segments = route.segments.select{|s| processable_segment2(s)}

      # Generate the tokens that make up the single statement in this fn
      tokens = processable_segments.inject([]) {|tokens, segment|
        is_var = segment.respond_to?(:key)
        prev_is_var = tokens.last.is_a?(Symbol)

        value = (is_var ? segment.key : segment.to_s)

        # Is the previous token ammendable?
        require_new_token = (tokens.empty? || is_var || prev_is_var)
        (require_new_token ?  tokens : tokens.last) << value

        tokens
      }

      # Convert strings to have quotes, and concatenate...
      statement = tokens.map{|t| t.is_a?(Symbol) ? t : "\"#{t}\""}.join("+")

      fn_params = processable_segments.select{|s|s.respond_to?(:key)}.map(&:key)

      "#{name}_path: function(#{fn_params.join(', ')}) {return #{statement};}"
    end

    save_js(filename, route_functions)
  end

  def self.generate_routes3(named_routes, filename)
    route_functions = named_routes.map do |name, route|
      processable_segments = route.conditions[:path_info].segments.select{|s| processable_segment3(s)}

      # Generate the tokens that make up the single statement in this fn
      tokens = processable_segments.inject([]) {|tokens, segment|
        is_var = segment.is_a?(Rack::Mount::GeneratableRegexp::DynamicSegment)
        prev_is_var = tokens.last.is_a?(Symbol)

        value = (is_var ? segment.name : segment.to_s)

        # Is the previous token ammendable?
        require_new_token = (tokens.empty? || is_var || prev_is_var)
        (require_new_token ?  tokens : tokens.last) << value

        tokens
      }

      # Convert strings to have quotes, and concatenate...
      statement = tokens.map{|t| t.is_a?(Symbol) ? t : "\"#{t}\""}.join("+")

      fn_params = processable_segments.select{|s|s.is_a?(Rack::Mount::GeneratableRegexp::DynamicSegment)}.map(&:name)

      "#{name}_path: function(#{fn_params.join(', ')}) {return #{statement};}"
    end

    save_js(filename, route_functions)
  end

  def self.save_js(filename, route_functions)
    File.open(filename, 'w') do |file|
      file << "var Routes = (function(){\n"
      file << "  return {\n"
      file << "    " + route_functions.join(",\n    ") + "\n"
      file << "  }\n"
      file << "})();"
      puts "Generated #{JavascriptRoutes::FILENAME}"
    end
  end

  def self.processable_segment2(segment)
    !segment.is_a?(ActionController::Routing::OptionalFormatSegment)
  end

  def self.processable_segment3(segment)
    segment.is_a?(String) || segment.is_a?(Rack::Mount::GeneratableRegexp::DynamicSegment)
  end

  def self.processable_named_routes2
    ActionController::Routing::Routes.named_routes.routes
  end

  def self.processable_named_routes3
    Rails.application.routes.named_routes.routes
  end
end
