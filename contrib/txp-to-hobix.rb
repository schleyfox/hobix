#
# txp_to_hobix.rb
#
# Converts a textpattern xml dump file generated with sqldump into a set of Hobix YAML entry files.
#
# Hobix::Entry code lifted from http://www.anvilwerks.com/src/wordpress_to_hobix.rb 
#
# (c) 2005 erngui.com
#
require "rexml/document"
include REXML  # so that we don't have to prefix everything with REXML::...

require "hobix"
require "hobix/entry"
require "fileutils"
require "parsedate"

txpdump = ARGV.shift
outdir = ARGV.shift

usage = <<EOT
Usage: 

  ruby txp_to_hobix.rb <txp dump file> <output directory>

     Converts a textpattern xml dump file generated with sqldump into a set of Hobix YAML entry files.

EOT

unless txpdump and outdir
  puts usage
  exit(1) 
end

txpexport = Document.new File.new(txpdump)
FileUtils.mkdir_p outdir

txpexport.elements.each("*/textpattern") do |e|
  entry = Hobix::Entry.new()
  entry.title = e.elements["Title"].text
  entry.author = e.elements["AuthorID"].text
    res = ParseDate.parsedate(e.elements["Posted"].text)
    posted = Time.local(*res)
  entry.created = posted
  entry.summary = e.elements["Excerpt"].text if e.elements["Excerpt"].text
  entry.content = e.elements["Body"].text
  
  # use the post title as filename after removing dodgy characters
  yamlfile = File.join(outdir, e.elements["Title"].text.downcase.tr(" :?!", "-").gsub(/[^a-zA-Z0-9-]+/, "") + ".yaml")
  
  puts "writing: #{yamlfile}"
  puts yamlfile.gsub(/(\w)\w*/, '\1').tr("-", "")
  File.open(yamlfile, "w") do |f|
     f.write(entry.to_yaml + "\n")
  end
end
