require 'cgi'

# Since method, calculate distance since data
def since( time )
    num = Time.now.to_i - time.to_i
    num = 1 if num < 1

    disp = "second"
    if num < 60
    elsif num < 60 * 60
        num /= 60
        disp = "minute"
    elsif num < 60 * 60 * 24
        num /= 60 * 60
        disp = "hour"
    else
        num /= 60 * 60 * 24
        disp = "day"
    end
    "#{ num } #{ disp }#{ 's' if num > 1 } ago"
end

# RedHanded-specific alterations
module Hobix

    class Entry

        # Returns an Array of fields to which the text processor applies.
        def Entry::text_processor_fields; ['title', 'content', 'tagline', 'summary']; end

        # All entries should have the 'ruby' keyword in the feeds.
        def force_keywords; ['ruby']; end

        # Build a brief summary excerpt for the archives.
        def summary_line
            ( summary || content ).to_html.gsub( /<[^>]+>/m, '' ).match( /(\w.{10,100})[.?!\)]+|^(\w.{10,100})\s/ ).to_a[0]
        end

        # Count words in an entry.
        def word_count
            content.scan( /(\w[\w'-]*)/ ).length
        end

        # Deal with end-of-entry blanks!!
        def content
            ( @content || "" ).strip
        end

    end

    class Weblog

        # Sidebar is an SSI, to allow me to change the sidebar wihtout needing to regenerate the
        # entire site.  This is nice as I'm occassionally adding links.
        def skel_sidebar( path_storage )
            months = path_storage.get_months( storage.find )
            page = Page.new( 'sidebar' )
            page.updated = Time.now
            yield :page => page, :months => months
        end

    end

    class LinkList

        # I'm not using Textile in the sidebar, so let's just generate HTML directly.
        def content
            str = @links.collect do |title, url|
                "<a href=\"#{ CGI.escapeHTML url }\">#{ CGI.escapeHTML title }</a><br />"
            end.join( "\n" )
            def str.to_html; to_s; end
            str
        end

    end

    class Out::QuickArchive

        # Entries listed on archive pages get a link, a word count, and an excerpt.
        def entry_erb
         %{ <h3 class="entryTitle"><a href="<%= entry.link %>"><%= entry.title %></a> (<%= entry.word_count %> words)</h3>
            <div class="entryShortSummary"><%= entry.summary_line %></div> }
        end

    end

    class Out::QuickSummary 

        # On summary pages (i.e. index.html), show summary and "Continue" link.  If no summary is found,
        # show complete entry text.
        def entry_content_erb
         %{ <div class="entryContent">
            <% if entry.summary %>
            <%= entry.summary.to_html %>
            <p><a href="<%= entry.link %>">Continue to full post.</a> <em>(<%= entry.word_count %> words)</em></p>
            <% else %>
            <%= entry.content.to_html %>
            <% end %>
            </div> }
        end

    end

end
