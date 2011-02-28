require 'yaml'

class Todoscan
	@@debug = true

	def initialize(directory = ".")
		@tasks = Array.new
		@configfile = "todo.cfg.yml"
		@config = loadConfig(@configfile)
		@directory = directory
		@out = $stdout

		keywordMatch = @config['todo_notations'].keys.join("|")
		@regex = /(#{keywordMatch}):\s+(.*?)$/i
	end

	def run()
		@tasks = getExistingTasks unless @config['force_overwrite']

		writemode = @config['force_overwrite'] ? "w" : "a+"
		@out = File.open(@config['filename'], writemode) if @config['filename']

		scandir(@directory)

		puts "" if @@debug

		@out.close if @config['filename']

		printTodo if @config['print_result']
	end

	def printTodo()
		f = File.open(@config['filename'], "r")
		lines = f.readlines()
		lines.each do | line |
			puts line
		end
		f.close
	end

	private

	def loadConfig(filename = "todo.cfg.yml")
		unless File.exists? filename
			file = File.open(filename, "w") 
			file << "
# The filename of the todo file, comment the follow line if no file should be written to.
filename:           'todo.txt'

# Todo-keywords are listed here, they are mapped to a priority (you can opt out by specifying an empty string)
todo_notations:
                    FIXME:  'A'
                    TODO:   ''

# If true, the program will write the contents of todo.txt to stdout.
print_result:       true

# If true the todo file will be overwritten everytime this file is run.
# If false it will try to detect what todo's already exists and only add new ones
force_overwrite:    true

# Tags each line with the name of the current directory, compliant with the todo.txt standard.
tag_with_project:   true

# Regexp rules for replacing naming the location of the task see http://www.ruby-doc.org/core/classes/String.html#M001186 for more information.
# Macros: $line
location_pattern:   ['^.*?/([^/]+/)?([^/]+)$', '...\\1\\2:$line']

# Define any tags here, defined macros are $filename, $directory, $fileextension
# Note: Spaces ( ) will be replaced by dashes (-)
tags:               ['code-$fileextension']

# Define exclusions here. All exclusions are regular expressions.
# 'files' is an array of filenames only, 'dirs' are directory names and 'paths' matches full paths.
exclude:
    files:          []
    dirs:           ['.git$', '.svn$']
    paths:          []
# Inclusions go here. Only files which matches these patterns will be included.
# If no patterns are defined, all files will be included (except for any exclusion rules)
include:
    files:          ['.c(pp|c|xx|s)?$', '.d$', '.h$', '.m$', '.php.?$', '.x?html?$', '.xml$', '.js$', '.css$', '.md$', '.textile$', '.java$', '.pl$', '.bat$', '.lua$', '.py.?$', '.rb$', '.sh$']
    dirs:           []
    paths:          []
"
			file.close
		end

		return YAML.load_file(filename)
	end


	def getExistingTasks()
		tasks = Array.new

		f = File.open(@config['filename'], "r")
		lines = f.readlines()
		lines.each do | line |
			line = line.gsub(/@[^\s]+ /, "") # Remove tags
			line = line.gsub(/\+[^\s]+ /, "") # Remove projects
			line = line.gsub(/ \([^\)]*\)$/, "") # Remove location
			line = line.gsub(/\(.\) /, "") # Remove priority?
			line = line.gsub("\n", "")
			matches = line.match(/^[^']*'(.+)'[^']*$/)

			tasks << matches[1] if matches
		end
		f.close

		return tasks
	end

	def valid_path?(path)
		if File.directory? path
			dirname = File.basename(path)
			return false if dirname == "." or dirname == ".."
			return false if excluded?(dirname, @config['exclude']['dirs'])
			return false if @config['include']['dirs'].count > 0 and not included?(dirname, @config['include']['dirs'])
			return false if excluded?(path, @config['exclude']['paths'])
		else
			filename = (File.directory?(path) ? '' : File.basename(path))
			return false if excluded?(filename, @config['exclude']['files'])
			return false if @config['include']['files'].count > 0 and not included?(filename, @config['include']['files'])
			return false if path[2..-1] == @config['filename']
			return false if path == "./"+@configfile
		end
		return false if @config['include']['paths'].count > 0 and not included?(path, @config['include']['paths'])
		return false unless File.readable?(path)
		return true
	end

	def scandir(dir)
		#puts "Scanning directory '#{dir}'..."
		Dir.new(dir).entries.each do | filename |
			path = dir+"/"+filename
			print "." if @@debug
			next unless valid_path?(path)

			if File.directory? path
				scandir(path) unless @config['exclude']['dirs'] and excluded?(filename, @config['exclude']['dirs'])
				next
			end

			file = File.open(path, "r")
			lines = file.readlines();
			print "[" if @@debug
			lines.each_with_index do | line, linenumber |
				todo = line.match(@regex)
				writeEntry(todo[2], path, linenumber+1, @config['todo_notations'][todo[1]]) if todo
				print "!" if @@debug and todo
			end
			print "]" if @@debug
		end
	end

	def excluded? (filename, excludes)
		excludes.each do | pattern |
			return true if filename.match(pattern)
		end
		return false
	end

	def included? (filename, includes)
		includes.each do | pattern |
			return true if filename.match(pattern)
		end
		return false
	end

	# https://github.com/ginatrapani/todo.txt-cli/wiki/The-Todo.txt-Format
	def writeEntry(task, location, line, priority)
		return if @tasks.include? task

		project = File.basename(Dir.getwd)

		replace = @config['location_pattern'][1].gsub("$line", line.to_s)
		url = location.gsub(Regexp.new(@config['location_pattern'][0]), replace)

		@out << "(" << priority << ") " if priority != ""
		@out << "+" << project << " " if @config['tag_with_project']
		@config['tags'].each do | tag |
			tag = tag.gsub(" ", "-")
			tag = tag.gsub("$filename", File.basename(location))
			tag = tag.gsub("$directory", File.basename(File.dirname(location)))
			if File.extname(location) and File.extname(location)[1..-1]
				tag = tag.gsub("$fileextension", File.extname(location)[1..-1]) 
			else
				tag = tag.gsub("$fileextension", File.basename(location))
			end
			@out << "@" << tag << " "
		end
		@out << "'" << task << "'"
		@out << " (" << url << ")"
		@out << "\n"
		@out.flush
	end
end


s = Todoscan.new
s.run