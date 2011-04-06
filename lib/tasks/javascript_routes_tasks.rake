namespace :routes do
  namespace :js do

    desc 'Generate routes.js based on routes defined in routes.rb'
    task :generate => :environment do
      ActionController::Routing::Routes.load!
      JavascriptRoutes.generate
      puts "Generated #{JavascriptRoutes::FILENAME}"
    end

    desc 'Minify the routes.js base file'
    task :minify => :environment do
      infile = JavascriptRoutes::FILENAME
      outfile = JavascriptRoutes::FILENAME_PACKED

      File.open(infile, 'r') do |input|
        File.open(outfile, 'w') do |output|
          JSMin.new(input, output).jsmin
        end
      end

      puts "#{File.size(infile)}   #{infile}"
      puts "#{File.size(outfile)}   #{outfile}"
    end
  end
end
