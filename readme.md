# Todo.txt Autoscan Utility

## Example session

Let's say you have some sort of code / text project you are working on, which supports some kind of comments:

    Deathstar/doc/usermanual.tex
    Deathstar/doc/usermanual.pdf
    Deathstar/laser_controller.c
    Deathstar/gravitionaltravel_handler.c
    Deathstar/...

Now, in all these files you maybe are writing stuff like

    // TODO: Make sure laser cannon does not overheat.

After working for a couple of decades on this project, you probably have a few dozen of these comments laying around (at least I do). 

This little utility will find all these comments and compile them into a neat [todo.txt](https://github.com/ginatrapani/todo.txt-cli)-compliant todo.txt file.

For example:

    (A) +Deathstar @code-c @laser_controller Make sure laser canon does not overheat. (laser_controller.c)

It also has the capability of just modifying any existing todo.txt file. (**Note:** Since this program is under development and very untested, it might just ruin your entire todo.txt-file. _Use with care!_)

    (A) Research X-wing fighters
    +Groceries Buy milk
    (A) +Deathstar @code-c @laser_controller Make sure laser canon does not overheat. (laser_controller.c)
    

## Installation

If you have any experience with ruby scripts, you should have no problem figuring out how to run and install this.

### Quick n' dirt

1. Make sure you have a ruby runtime environment installed.
2. Put `todoscan.rb` in your project directory
3. Execute `todoscan.rb` with your ruby installation.

A file called `todo.cfg.yml` and one called `todo.txt`should have been created. Open up `todo.cfg.yml` to configure the behaviour.

### Install as an alias

#### Windows

1. Create a file called `todoscan.bat` in a directory of your choice.
2. Type the following into it: (replace the path with where your todoscan.rb is)

    `@echo off`
    
    `ruby "C:\path\to\todoscan.rb" %*`

3. [Set your PATH variable](http://geekswithblogs.net/renso/archive/2009/10/21/how-to-set-the-windows-path-in-windows-7.aspx) to include the directory which contains `todoscan.bat` 

Now you can use it by simply opening up a console in the directory you want to autoscan (Shift + Right click -> Open command line here) and type `todoscan` along with any parameters you need.

#### *nix / Mac

TO-DO: Explain/link to how you set up an alias.

### As a git hook

TO-DO: Find out how git-hooks works and write down how to set it up with todoscan

### As a subversion hook

TO-DO: Find out how svn-hooks works and write down how to set it up with todoscan

### As a sublime-text plugin

TO-DO: Find out how sublime text plugins works and write down how to set it up with todoscan
