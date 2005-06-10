#
# = hobix/publish/replicate.rb
#
# FTP Replication for Hobix.
#
# Copyright (c) 2003-2004 why the lucky stiff
#
# Written by Frederick Ros <sl33p3r@free.fr>
# Maintained by why the lucky stiff <why@ruby-lang.org>
#
# This program is free software, released under a BSD license.
# See COPYING for details.
#
#--
# $Id$
#++
require 'hobix/base'
require 'net/ftp'
require 'fileutils'

module Publish

  Target = Struct.new( :path, :host, :user, :passwd )

  class PublishReplication < Hobix::BasePublish
    attr_reader :replicator, :weblog

    def initialize( weblog, hash_opt )
        @weblog = weblog
        hash_opt['items'] = nil
        hash_opt['source'] = weblog.output_path
        
        if hash_opt['target'] =~ /^ftp:\/\/([^:]+):([^@]+)@([^\/]+)(\/.*)$/
          tgt = Target.new($4,$3,$1,$2)

          @replicator = ReplicateFtp::new(hash_opt, tgt)
        else
          #
          # File replication
          #
          tgt = Target.new(hash_opt['target'])
          @replicator = ReplicateFS.new(hash_opt, tgt)	  

        end
    end

    def watch
      ['index']
    end

    def publish( published )
      replicator.items = weblog.updated_pages.map { |o| o.link }
      replicator.copy do |nb,f,src,tgt|
        puts "## Replicating #{src}"
      end
    end
end
end

module Hobix
  class Weblog
    attr_reader :updated_pages
    
    alias p_publish_orig p_publish

    def p_publish( obj )
      (@updated_pages ||= []) << obj
      p_publish_orig( obj )
    end

  end
end


class Replicate

  attr_accessor :items, :target, :source

  def initialize(hash_src, hash_tgt)
    @items = hash_src['items']
    @source = hash_src['source']
    @target = hash_tgt['path']

  end


  DIRFILE = /^(.*\/)?([^\/]*)$/

  def get_dirs
    dirs = Array.new

    dirfiles = items.collect do |itm|
      dir,file =  DIRFILE.match(itm).captures

      if dir && dir.strip.size != 0
	dirs.push dir
      end
    end
    
    dirs
  end

  def get_files
    files = Array.new
    dirfiles = items.collect do |itm|
      dir,file =  DIRFILE.match(itm).captures

      if file && file.strip.size != 0
	files.push itm
      end
    end
    
    files
  end

  def check_and_make_dirs
    dirs = get_dirs

    dirs.each do |dir|
      # Check existence and create if not present
      dir = File.join(target,dir)
      if !directory?(dir) 
	# Let's create it !
	mkdir_p(dir)
      end
    end      
  end


  def copy_files ( &block)
    files = get_files

    nb_files = files.size

    files.each do |file|

      src_f = File.join(source,file)
      tgt_f = File.join(target,file)
	
      if block_given?
	yield nb_files,file, src_f, tgt_f
      end

      cp(src_f,tgt_f)      
    end
  end


  def copy (&block)
    if respond_to?(:login)
      send :login
    end

    check_and_make_dirs

    copy_files &block

    if respond_to?(:logout)
      send :logout
    end

  end

end


class ReplicateFtp < Replicate

  attr_accessor :ftp, :passwd, :user, :host

  def initialize(hash_src, hash_tgt) 
    super(hash_src,hash_tgt)

    @user = hash_tgt['user']
    @passwd = hash_tgt['passwd']
    @host = hash_tgt['host']

  end

  def login
    @ftp = Net::FTP.open(host)
    ftp.login user,passwd
  end

  def logout
    ftp.close
  end

  def directory?(d)
    old_dir = ftp.pwd

    begin
      ftp.chdir d
      # If we successfully change to d, we could now return to orig dir
      # otherwise we're in the rescue section ...
      ftp.chdir(old_dir)
      return true

    rescue Net::FTPPermError
      if $!.to_s[0,3] == "550"
	# 550 : No such file or directory
	return false
      end
      raise Net::FTPPermError, $!
    end
  end


  def mkdir_p(tgt)
    old_dir = ftp.pwd
    tgt.split(/\/+/).each do |dir|
      next if dir.size == 0
      # Let's try to go down
      begin
	ftp.chdir(dir)
	# Ok .. So it was already existing ..
      rescue Net::FTPPermError
	if $!.to_s[0,3] == "550"
	  # 550 : No such file or directory : let's create ..
	  ftp.mkdir(dir)
	  # and retry
	  retry
	end
	raise Net::FTPPermError, $!
      end
    end
    ftp.chdir(old_dir)

  end


  def cp(src,tgt)
    ftp.putbinaryfile src, tgt
  end
end

class ReplicateFS < Replicate

  def directory?(d)
    File.directory? d
  end

  def mkdir_p(tgt)
    FileUtils.mkdir_p tgt
  end

  def cp(src,tgt)
    FileUtils.cp src, tgt
  end

end
