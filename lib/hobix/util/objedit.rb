#
# = hobix/util/objedit
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
require 'ncurses'
require 'yaml'

module Hobix
module Util
# The ObjEdit class provides an ncurses-based editor for
# modifying Ruby objects.  The ncurses library must be installed,
# which is available at http://ncurses-ruby.berlios.de/.
def self.ObjEdit( obj )
    include Ncurses
    include Ncurses::Form
    # Initialize ncurses
    scr = Ncurses.initscr
    out_obj = nil
    Ncurses.start_color
    Ncurses.cbreak
    Ncurses.keypad scr, true

    # Initialize few color pairs 
    Ncurses.init_pair 1, COLOR_RED, COLOR_BLACK
    Ncurses.init_pair 2, COLOR_BLACK, COLOR_WHITE
    Ncurses.init_pair 3, COLOR_BLACK, COLOR_BLUE
    scr.bkgd Ncurses.COLOR_PAIR(2) 

    # Initialize the fields
    y = 0
    labels = []
    label_end = 12
    ivars = []
    fields =
        obj.property_map.collect do |ivar, flag, edit_as|
            ht, wt = 1, 30
            case edit_as
            when :text
                field = FIELD.new ht, wt, y, 1, 0, 0
            when :textarea
                ht, wt = 5, 50
                field = FIELD.new ht, wt, y, 1, 60, 0
            end
            labels << [y + 2, ivar, ht, wt]
            ivars << ivar
            label_end = ivar.length + 3 if label_end < ivar.length + 3
            y += ht + 1

            field.set_field_back A_UNDERLINE
            field_write( field, obj.instance_variable_get( ivar ) )
            field
        end

    # Create the form
    my_form = FORM.new fields
    my_form.user_object = "Editing #{ obj.class }"
    rows, cols = [], []
    my_form.scale_form rows, cols

    # Create the window
    my_win = WINDOW.new rows[0] + 3, cols[0] + 20, 0, 0
    my_win.bkgd Ncurses.COLOR_PAIR( 3 )
    my_win.keypad TRUE
    labels.each do |y, ivar, ht, wt|
        my_win.mvaddstr y, 2, ivar
    end

    # Attach
    my_form.set_form_win my_win
    my_form.set_form_sub my_win.derwin( rows[0], cols[0], 2, label_end )
    my_form.post_form
    my_win.wrefresh

    # Loop through to get user requests
    my_form.form_opts_off O_NL_OVERLOAD
    while((ch = my_win.getch()) != KEY_F1)
        case ch
        when ?\t
            # Go to next field
            my_form.form_driver REQ_VALIDATION
            my_form.form_driver REQ_NEXT_FIELD
            # Go to the end of the present buffer
            # Leaves nicely at the last character
            my_form.form_driver REQ_END_LINE
          
        # when KEY_UP
        #     # Go to previous field
        #     my_form.form_driver REQ_VALIDATION
        #     my_form.form_driver REQ_PREV_FIELD
        #     my_form.form_driver REQ_END_LINE

        when KEY_UP
            my_form.form_driver REQ_PREV_LINE

        when KEY_DOWN
            my_form.form_driver REQ_NEXT_LINE

        when KEY_LEFT
            # Go to previous character
            my_form.form_driver REQ_PREV_CHAR

        when KEY_RIGHT
            # Go to previous field
            my_form.form_driver REQ_NEXT_CHAR

        when KEY_BACKSPACE, 010
            my_form.form_driver REQ_DEL_PREV

        when KEY_ENTER, ?\n, ?\r
            my_form.form_driver REQ_NEW_LINE

        else
            # If this is a normal character, it gets Printed    
            my_form.form_driver ch
        end
    end
    # Un post form and free the memory
    my_form.unpost_form
    my_form.free_form
    obj_props = {}
    fields.each do |f|
        b = field_read(f)
        f.free_field()
        obj_props[ivars.shift] = b
    end
    out_obj = YAML::object_maker( obj.class, obj_props )
    nil
ensure
    Ncurses.endwin
    p out_obj
end
def self.field_write( f, obj )
    rows, cols, frow, fcol, nrow, nbuf = [], [], [], [], [], []
    f.field_info( rows, cols, frow, fcol, nrow, nbuf )
    if String === obj
        obj = "#{ obj }"
    end
    str = obj.to_yaml( :BestWidth => cols[0] - 4 ).
              sub( /^\-\-\-\s*(\>\n)?/, '' ).
              gsub( /^([^\n]*)\n/ ) { |line| "%-#{cols}s" % [$1] }
    f.set_field_buffer 0, str
end
def self.field_read( f )
    rows, cols, frow, fcol, nrow, nbuf = [], [], [], [], [], []
    f.field_info( rows, cols, frow, fcol, nrow, nbuf )
    val = f.field_buffer(0).scan( /.{#{ cols[0] }}/ )
    YAML::load(
        if val.length > 1
            "--- >\n  " + 
            val.collect { |line| line.rstrip }.join( "\n  " ).rstrip
        else
            "--- #{ val[0] }"
        end
    )
end
end
end
