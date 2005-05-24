#
# = hobix/out/okaynews.rb
#
# YAML !okay/news output for Hobix.
#
# Copyright (c) 2003-2004 why the lucky stiff
#
# Written & maintained by why the lucky stiff <why@ruby-lang.org>
#
# This program is free software, released under a BSD license.
# See COPYING for details.
#
#--
# $Id$
#++
require 'hobix/base'

module Hobix
class Weblog
    def to_okaynews( entries ) 
        YAML::quick_emit( self.object_id ) do |out|
            out.map( "!okay/news/^feed" ) do |map|
                ['@title', '@tagline', '@link', '@period',
                 '@created', '@issued', '@modified',
                 '@authors', '@contributors'
                ].each do |m|
                    map.add( m[1..-1], instance_variable_get( m ) )
                end
                entries = entries.collect do |e|
                    e = e.dup
                    e.author = @authors[e.author]
                    def e.to_yaml_type
                        "!^entry"
                    end
                    e
                end
                map.add( 'entries', entries )
            end
        end
    end
end
module Out
class OkayNews < Hobix::BaseOutput
    def initialize( weblog )
        @path = weblog.skel_path
    end
    def extension
        "okaynews"
    end
    def load( file_name, vars )
        vars[:weblog].to_okaynews( vars[:entries] )
    end
end
end
end
