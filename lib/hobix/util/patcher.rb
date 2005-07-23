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
# The Patcher class applies Hobix's own YAML patch format to a directory.
# These patches can create or append to existing plain-text files, as well
# as modifying YAML files using YPath.
#
# To apply your patch:
#
#   patch_set = Hobix::Util::Patcher['1.patch', '2.patch']
#   patch_set.apply('/dir/to/unaltered/code')
#
class PatchError < Exception; end
class Patcher
    # Initialize the Patcher with a list of +paths+ to patches which
    # must be applied in order.
    #
    #   patch_set = Hobix::Util::Patcher.new('1.patch', '2.patch')
    #   patch_set.apply('/dir/to/unaltered/code')
    #
    def initialize( *paths )
        @patches = {}
        paths.each do |path|
            YAML::load_file( path ).each do |k, v|
                ( @patches[k] ||= [] ) << v
            end
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
        @patches.map do |fname, patchset|
            fname = File.join( path, fname ) # .gsub( /^.*?[\/\\]/, '' ) )
            ftarg = File.read( fname ) rescue ''
            ftarg = YAML::load( ftarg ) if fname =~ /\.yaml$/
            
            patchset.each_with_index do |(ptype, patch), patchno|
                # apply the changes
                puts "*** Applying patch ##{ patchno + 1 } for #{ fname } (#{ ptype })."
                ftarg = method( ptype.gsub( /\W/, '_' ) ).call( ftarg, patch )
            end

            [fname, ftarg]
        end.
        each do |fname, ftext|
            # save the files
            if ftext == :remove
                FileUtils.rm_rf fname
            else
                FileUtils.makedirs( File.dirname( fname ) )
                ftext = ftext.to_yaml if fname =~ /\.yaml$/
                File.open( fname, 'w+' ) { |f| f << ftext }
            end
        end
    end

    def file_remove( target, text )
        :remove
    end

    def file_create( target, text )
        text.to_s
    end

    def file_ensure( target, text )
        target << text unless target.include? text
        target
    end

    def yaml_merge( obj, merge )
        obj = obj.value if obj.respond_to? :value
        if obj.class != merge.class and merge.class != Hash
            raise PatchError, "*** Patch failure since #{ obj.class } != #{ merge.class }."
        end

        case obj
        when Hash
            merge.each do |k, v|
                if obj.has_key? k
                    yaml_merge obj[k], v
                else
                    obj[k] = v
                end
            end
        when Array
            at = nil
            merge.each do |v|
                vat = obj.index( v )
                if vat
                    at = vat if vat > at.to_i
                else
                    if at
                        obj[at+=1,0] = v
                    else
                        obj << v
                    end
                end
            end
        when String
            obj.replace merge
        else
            merge.each do |k, v|
                ivar = obj.instance_variable_get "@#{k}"
                if ivar
                    yaml_merge ivar, v
                else
                    obj.instance_variable_set "@#{k}", v
                end
            end
        end

        obj
    end
end
end
end

YAML::add_domain_type( 'hobix.com,2004', 'patches/list' ) do |type, val|
    val
end
['yaml-merge', 'file-create', 'file-ensure', 'file-remove'].each do |ptype|
    YAML::add_domain_type( 'hobix.com,2004', 'patches/' + ptype ) do |type, val|
        [ptype, val]
    end
end
