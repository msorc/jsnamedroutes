module JavascriptRoutes

  FILENAME = File.join(RAILS_ROOT, 'public', 'javascripts', 'routes.js')
  FILENAME_PACKED = File.join(RAILS_ROOT, 'public', 'javascripts', 'routes-min.js')

  # Generate...
  #
  # Options are:
  #  :filename      => name of routes javascript file (default routes.js)
  #
  #  :lite => only generate functions, not the unnamed generational routes (i.e. from controller/action)
  #
  #  :pack => use the packed version
  #
  #  :routes       - which routes (leave out for all)
  #  :named_routes - which named routes (leave out for all)
  #
  #
  def self.generate(options = {})
    options.symbolize_keys!

    routes       = options[:routes] || processable_routes
    named_routes = options[:named_routes] || processable_named_routes

    filename = options[:filename] || FILENAME

    # Create one function per route (simple lite version...)
    generate_lite(named_routes, filename)

  rescue => e
    warn("\n\nCould not write routes.js: \"#{e.class}:#{e.message}\"\n\n")
    File.truncate(filename, 0) rescue nil
  end


  def self.generate_lite(named_routes, filename)
    route_functions = named_routes.map do |name, route|
      processable_segments = route.segments.select{|s| processable_segment(s)}

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

    File.open(filename, 'w') do |file|
      file << "var Routes = (function(){\n"
      file << "  return {\n"
      file << "    " + route_functions.join(",\n    ") + "\n"
      file << "  }\n"
      file << "})();"
    end
  end

  def self.processable_segment(segment)
    !segment.is_a?(ActionController::Routing::OptionalFormatSegment)
  end


  def self.processable_routes
    ActionController::Routing::Routes.routes
  end


  def self.processable_named_routes
    ActionController::Routing::Routes.named_routes.routes
  end
end
