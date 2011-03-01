require 'optparse'
require 'yaml'

# The Todoscan program scans directory for TODO-annotations within any specified
# file. When first run, it will create a config file in the current directory,
# use it to configure the programs behaviour.
# 
# This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
class Todoscan

  # Initializes the todo scanner with the correct environment
  def initialize(options)
    @tasks      = Array.new
    @configfile = options[:config_file]
    @config     = load_config(@configfile)
    @directory  = options[:directory]
    @verbose    = options[:verbose]
    @recursive  = @config['recursive'] && options[:recursive]
    @out        = $stdout

    keyword_match = @config['todo_notations'].keys.join("|")
    @regex = /(#{keyword_match}):\s+(.*?)$/i

    # User-friendly way of notifying of invalid directory?
    if not File.readable? @directory
      $stderr.puts "Error: The specified directory '#{@directory}' can not be read. \nMake sure the directory exists and that you have enough permissions to read it."
      exit
    end
  end

  # Runs the program itself
  def run
    @tasks = get_existing_tasks unless @config['force_overwrite']

    # Open the file in the correct mode.
    writemode = @config['force_overwrite'] ? "w" : "a+"
    @out = File.open(@config['filename'], writemode) if @config['filename']

    puts "Scanning directory '#{@directory}' for tasks..." if @verbose

    # Scan all directories recursively? and output all tasks
    scandir(@directory)

    # We're done writing, close the file.
    @out.close if @config['filename']

    # TO-DO: Compare this result against the existing todo.txt and figure out what is new, and what has been completed. (Add ability to move completed items onto a changelog of sorts? what does todo.txt do?)

    # Print the result
    if @verbose
      puts "\nDone scanning."
      puts "Result:\n\n"
      print_todo
    end
  end

  # TO-DO: Comment print_todo
  def print_todo
    f = File.open(@config['filename'], "r")
    lines = f.readlines()
    lines.each do | line |
      puts line
    end
    f.close
  end

  private

  # TO-DO: Comment load_config
  def load_config(filename = "todo.cfg.yml")
    unless File.exists? filename
      file = File.open(filename, "w") 
      file << "
# The filename of the todo file, comment the follow line if no file should be written to.
filename:           'todo.txt'

# Set to true if subdirs should be scanned
recursive:          true

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
    files:          ['^todoscan.rb$']
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

  # Tries to read and parse existing tasks in the todo.txt
  def get_existing_tasks
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

  # Scans a directory for files containing the todo notations.
  def scandir(dir)
    Dir.new(dir).entries.each do | filename |
      path = dir+"/"+filename
      print "." if @verbose
      next unless valid_path?(path)

      if File.directory? path
        scandir(path) if @recursive
        next
      end

      file = File.open(path, "r")
      lines = file.readlines();
      print "[" if @verbose
      lines.each_with_index do | line, linenumber |
        todo = line.match(@regex)
        write_entry(todo[2], path, linenumber+1, @config['todo_notations'][todo[1]]) if todo
        print "!" if @verbose and todo
      end
      print "]" if @verbose
    end
  end

  # Returns true a certain path is valid according to the configured rules.
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

  # Returns true if a filename is included by the given exclusion rules
  def excluded? (filename, excludes)
    excludes.each do | pattern |
      return true if filename.match(pattern)
    end
    return false
  end

  # Returns true if a filename is included by the given inclusion rules
  def included? (filename, includes)
    includes.each do | pattern |
      return true if filename.match(pattern)
    end
    return false
  end

  # Write a todo.txt-compliant entry to the file stored in @out.
  # For the format spec, see https://github.com/ginatrapani/todo.txt-cli/wiki/The-Todo.txt-Format
  def write_entry(task, location, line, priority)
    # TO-DO: Merely store the result in an array to enable better data handling.
    return if @tasks.include? task

    return if task.strip.length == 0 # Ignore empty tasks
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
    @out << "'" << task.strip << "'"
    @out << " (" << url << ")"
    @out << "\n"
    @out.flush
  end
end

options = {}
options[:directory] = "."
options[:verbose] = false
options[:recursive] = true
options[:config_file] = "todo.cfg.yml"

optparse = OptionParser.new do | opts |
  opts.banner = "Usage: todoscan.rb [options]"
  opts.separator ""
  opts.separator "Options:"

  opts.on("-c CONFIG_FILE", "--config-file", "Specify where the config file exist, default is '#{options[:config_file]}'.") do | file |
    options[:config_file] = file
  end

  opts.on("-d DIR", "--directory", "Specify what directory to scan.") do | dir |
    options[:directory] = dir
  end

  opts.on("-R", "--no-recursion", "Only scans the target directory. Overrides config file.") do 
    options[:recursive] = false
  end

  opts.on("-v", "--verbose", "Output extra information while running.") do 
    options[:verbose] = true
  end

  opts.on("-h", "--help", "Show this message.") do 
    puts opts
    exit
  end
end

optparse.parse!

s = Todoscan.new(options)
s.run
