#
# = hobix/util/patcher
#
# Hobix command-line weblog system.
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
require 'fileutils'

module Hobix
module Util
# The Patcher class applies unified diffs to a directory of files.
# The idea here is to allow cross-platform patching, even if this
# class only understands a subset of diff syntax.
#
# Best results are achieved by using the following diff command to 
# generate your patch:
#
#   diff -wurP original-dir/ patched-dir/ > unified.patch
#
# Then to apply your patch:
#
#   patch_set = Hobix::Util::Patcher['1.patch', '2.patch']
#   patch_set.apply('/dir/to/unaltered/code')
#
class Patcher
    FILENAME_RE = /[\w\.\/\\]+/
    ORIG_HEADER = /^---\s+(#{ FILENAME_RE })/
    PATCH_HEADER = /^\+\+\+\s+(#{ FILENAME_RE })/
    LINE_RANGE = /^@@\s+(.{1})(\d+),(\d+)\s+(.{1})(\d+)(?:,(\d+))?\s+@@/
    # Initialize the Patcher with a list of +paths+ to patches which
    # must be applied in order.
    #
    #   patch_set = Hobix::Util::Patcher.new('1.patch', '2.patch')
    #   patch_set.apply('/dir/to/unaltered/code')
    #
    def initialize( *paths )
        @patches = {}
        paths.each do |path|
            patch = {}
            File.foreach( path ) do |line|
                parse_line( line, patch )
            end
            parse_line( "", patch )
        end
    end

    # Alias for Patcher.new.
    #
    #   patch_set = Hobix::Util::Patcher['1.patch', '2.patch']
    #   patch_set.apply('/dir/to/unaltered/code')
    #
    def Patcher.[]( *paths )
        Patcher.new( *paths )
    end

    # Apply the patches loaded into this class against a +path+ containing
    # unaltered files.
    #
    #   patch_set = Hobix::Util::Patcher['1.patch', '2.patch']
    #   patch_set.apply('/dir/to/unaltered/code')
    #
    def apply( path )
        @patches.each do |fname, patchset|
            fname = File.join( path, fname.gsub( /^.*?[\/\\]/, '' ) )
            lines = 
                if File.exists?( fname )
                    File.readlines( fname )
                else
                    []
                end
            
            patchset.each_with_index do |patch, patchno|
                # match the chunk
                i = 0
                adds = []
                patch[:lines].each do |pline|
                    c = pline.slice!( 0, 1 )
                    if c =~ /[#{ Regexp::quote( patch[:from_char] ) }\s]/
                        ln = patch[:from_start] + i
                        if lines[ln] != pline
                            raise ChunkError, 
                                "chunk ##{ patchno + 1 } failed on '#{ pline.chomp }' != '#{ lines[ln] }' (line #{ ln })"
                        else
                            i += 1
                        end
                    end
                    if c =~ /[#{ Regexp::quote( patch[:to_char] ) }\s]/
                        adds << pline
                    end
                end

                # apply the changes
                puts "*** Applying patch ##{ patchno + 1 } for #{ fname } (#{ patch[:from_start] }, #{ patch[:from_len] })."
                lines[patch[:from_start], patch[:from_len]] = adds

                # save the file
                FileUtils.makedirs( File.dirname( fname ) )
                File.open( fname, "w" ) do |f|
                    lines.each do |line|
                        f.puts line.chomp
                    end
                end
            end

        end
    end

    def parse_line( line, patch )
        if patch.has_key? :from_count
            if patch[:from_count] == patch[:from_len] and patch[:to_count] == patch[:to_len]
                @patches[patch[:from_file]] ||= []
                @patches[patch[:from_file]] << patch.dup
                patch.clear
            else
                patch[:lines] ||= []
                patch[:lines] << line
                patch[:from_count] += 1 if line =~ /^[#{ Regexp::quote( patch[:from_char] )}\s]/
                patch[:to_count] += 1 if line =~ /^[#{ Regexp::quote( patch[:to_char] )}\s]/
            end
        end
        case line
        when ORIG_HEADER
            patch[:from_file] = $1
        when PATCH_HEADER
            patch[:to_file] = $1
        when LINE_RANGE
            patch[:from_char], patch[:to_char] = $1, $4
            patch[:from_start], patch[:to_start] = $2.to_i, $5.to_i
            patch[:from_len], patch[:to_len] = $3.to_i, $6.to_i
            patch[:from_count], patch[:to_count] = 0, 0
            patch[:from_start] -= 1 if patch[:from_start] > 0
            patch[:to_len] = 1 if patch[:to_len] == 0
        end
    end

    class ChunkError < Exception; end
end
end
end
