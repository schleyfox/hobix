#!/usr/bin/ruby -w

## VERSION 0.2
##
## This is a preliminary Blosxom to Hobix entry conversion
## script. Right now it's heavily biased towards the plugins and the
## subset of Blosxom that I used. Feel free to send me comments (or
## patches!) if it's not doing what you want.
##
## Example usage:
##
## ./blosxom-to-hobix.rb -e /usr/share/blosxom/plugins/state/.entries_index.index /var/www/blosxom/ /var/www/hobix/entries/ goatlord
##
## This will run over all the .blog files all in subdirectories of
## /var/www/blosxom, and convert them to .yaml files in the
## appropriate subdirectory of /var/www/hobix/entries/ (creating
## directories as needed), with the author set to 'goatlord'. It will
## set the creation times to the corresponding entry in the
## entries_index state file, or from the file's mtime otherwise. (If
## you don't use the entries_index plugin, you don't worry about the
## -e option.)
##
## Right now this will detect Tiki usage if it sees a //tiki line, and
## do some preliminary Tiki -> Textile conversion. I only used a small
## subset of the Tiki stuff, so don't expect this to do all the
## conversion right off the bat.
##
## I find that this works best with fold_lines turned on in RedCloth.
## I enable them via the following code in lib/local.rb:
##
## module Hobix
## 
## class RedClothFoldLines < RedCloth
##   def initialize(*args)
##     x = super(*args)
##     x.fold_lines = true
##     x
##   end
## end
##
## def Entry::text_processor; RedClothFoldLines; end
##
## Good luck. --William <wmorgan-b2h@masanjin.net> 9/17/04
##
## This file is released under the GNU Public License.

require 'optparse'
require 'find'
require 'yaml'
require 'hobix'

class Options
  def initialize # defaults
    @parse_tiki = true
    @entries_index = nil
    @overwrite = false

    @blosxom_extension = ".blog"
    @hobix_extension = ".yaml"
  end

  def parse(args)
    opts = OptionParser.new do |o|
      o.banner = "Usage: blosxom-to-hobix [options] <blosxom-root> <hobix-root>"
      o.separator ""
      o.separator "Where [options] are:"

      o.on("-t", "--no-parse-tiki", TrueClass,
           "Don't convert Tiki to Textile when found") do |fl|
        @parse_tiki = fl
      end

      o.on("-e", "--entries-index n", @entries_index.class,
           "Entries_index data file") do |s|
        @entries_index = s
      end

      o.on("-o", "--overwrite", TrueClass,
           "Overwrite destination files without mercy") do |fl|
        @overwrite = fl
      end

      o.on("-b", "--blosxom-extension", @blosxom_extension.class,
           "Blosxom filename extension (default: #@blosxom_extension)") do |s|
        @blosxom_extension = s
      end

      o.on("-x", "--hobix-extension", @hobix_extension.class,
           "Hobix filename extension (default: #@hobix_extension)") do |s|
        @hobix_extension = s
      end

      o.on_tail("-h", "--help", "Show this message") { puts opts ; exit }
    end

    opts.parse!(args)
    self
  end

  def method_missing(meth); instance_eval "@#{meth}"; end
end

def each_file(root, extension)
  Find.find(root) do |fn|
    yield fn if FileTest.file?(fn) && (fn =~ /#{extension}$/)
  end
end

def tiki_to_textile(s)
  @in_bq ||= false # in block-quote mode
  @in_pre ||= false # in pre mode

  ## this is kind of a mess.

  xend = '[\s,.\?!-]'

  map = {
    ## hack alert---inline urls in a pre-block we pull out of the pre block;
    ## otherwise they don't render.
    /^\s+(\w+:\/\/.+)(#{xend}|$)/ => '"\1":\1\2',

    ## inline urls
    /(^|\s)(\w+:\/\/.+)(#{xend}|$)/ => '\1"\2":\2\3',

    ## named urls
    /\[(.*?)\]:(.+?)(#{xend}|$)/ => '"\1":\2\3',

    ## images
    /\{(.*?)\}:(.+?)(#{xend}|$)/ => '!\2(\1)!\3',

    ## italics
    /(\s|^)\/(.+?)\/(#{xend}|$)/ => '\1_\2_\3',

    ## these two were local hacks i made to tiki (to emulate latex
    ## hyphenation styles), so they may not apply to you.
    /([^-])--([^-])/ => '\1-\2',
    /([^-])---([^-])/ => '\1--\2',
  }

  map.each { |k, v| s.gsub! k, v }

  if @in_bq
    if s =~ /^[^>]$/
      @in_bq = false
    elsif s =~ /^>\s*(\S.*)$/
      s = $1
    end
  elsif s =~ /^>\s*(\S.*)$/
    @in_bq = true
    s = "bq. " + $1
  end

  if @in_pre
    if (s =~ /^\S/) || (s =~ /^\s*$/)
      @in_pre = false
      s += "</pre>\n"
    end
  elsif s =~ /^\s+\S/
    s = "<pre>\n" + s
    @in_pre = true
  end

  s
end  

def convert(bf, hf, author, date, opts)
  title = bf.readline.chomp
  tiki = false
  content = ""

  bf.each_line do |l|
    if (l =~ /^\/\/Tiki/i) && opts.parse_tiki
      tiki = true 
    else
      l = tiki_to_textile(l) if tiki
      content += l.chomp + "\n" # force newline
    end
  end

  #puts "content is [#{content.chomp + "\n"}]"

  hf.write(Hobix::Entry.new do |e|
             e.title = title
             e.content = content.chomp + "\n"
             e.author = author
             e.summary = nil
             e.contributors = nil
             e.tagline = nil
             e.created = date
  end.to_yaml)
end

def rec_mkdir(path)
  if File.exists? path
    true
  else
    unless File.exists? File.dirname(path)
      rec_mkdir File.dirname(path)
    end
    Dir.mkdir path
  end
end

def run(broot, hroot, author, opts)
  entries_index = Hash.new

  if opts.entries_index
    IO.foreach(opts.entries_index) do |l|
      if l =~ /'(.*?)' => (\d+)/
        entries_index[$1] = $2
      end
    end
  end

  each_file(broot, opts.blosxom_extension) do |bfn|
    hfn = File.join hroot,
                    bfn.gsub(/^#{broot}\//, "").gsub(/#{opts.blosxom_extension}$/,
                                                opts.hobix_extension)
    unless File.exists? File.dirname(hfn)
      puts "## creating #{File.dirname(hfn)}"
      rec_mkdir File.dirname(hfn)
    end
    
    if File.exists?(hfn) && !opts.overwrite
      puts "## File #{hfn} already exists; skipping"
      next
    end

    puts "#{bfn} => #{hfn}"
    bfile = File.open(bfn, "r")
    hfile = File.open(hfn, "w")
    date = if entries_index[bfn]
             Time.at(entries_index[bfn].to_i)
           else
             File.mtime(bfile)
           end

    convert bfile, hfile, author, date, opts
    bfile.close
    hfile.close
  end
end

if $0 == __FILE__
  opts = Options.new.parse ARGV
  broot = ARGV.shift or
    raise "First argument must be a Blosxom root. Try '-h'"
  hroot = ARGV.shift or
    raise "Second argument must be a Hobix root. Try '-h'"
  author = ARGV.shift or raise "Third argument must be the author name. Try '-h'"

  run broot.gsub(/\/$/, ""), hroot.gsub(/\/$/, ""), author, opts
end
