## flickr.rb -- Hobix Flickr plugin
##
## Displays your Flickr photostream ("badge") on the sidebar.  This is
## based on the instructions at http://flickr.com/badge_new.gne. That
## page provides a lot more functionality in terms of colors and sizes
## and whatnot; this plugin just makes it slightly easier to do the
## most common thing.
##
## You'll need to discover your Flickr userid to use this (different
## from your username). You can use the tool at
## http://eightface.com/code/idgettr/, or simply examine your Flickr
## RSS URL for the "id" parameter.  It should look something like
## this: 34479244@N00.
##
## USAGE:
##
## 1) In hobix.yaml (e.g. by running 'hobix edit <blogname>'), in the
##    'required' block, append as follows:
##
## required:
##   - hobix/plugin/flickr:
##       userid: <your flickr userid (see above)>
##
##    You can also specify any of the following arguments:
##
## required:
##   - hobix/plugin/flickr:
##       userid: <your flickr userid>
##       num: <number of pics to use (default 5)>
##       size: <small, thumbnail or midsize (default small)>
##       title: <title (default "Recent Pictures"), or nil for none>
##       in-sidebarBox-div: <true or false (default true)>
##
## NOTES:
##
## 1) If you redefine 'sidebar_list' in hobix.yaml, you'll need to
##    explicitly add a 'sidebar_flickr' item.

module Hobix

## we just keep parameters from hobix.yaml here
class FlickrPlugin < BasePlugin
  def initialize(weblog, params = {})
    raise %{the flickr plugin needs a "userid" parameter. see hobix/plugin/flickr.rb for details} unless params.member? "userid"
    @@userid = params["userid"]
    @@num = params["num"] || 5
    @@size =
      case params["size"]
      when nil, "small"
        "s"
      when "thumbnail"
        "t"
      when "midsize"
        "m"
      else
        raise %{unknown size value "#{params["size"]}" for flickr plugin. use "small", "thumbnail" or "midsize"}
      end
    @@title = params["title"] || "Recent Pictures"
    @@in_sidebarBox_div = lambda { |x| (x.nil? ? true : x) }[params["in-sidebarBox-div"]]
  end

  def self.userid; @@userid; end
  def self.num; @@num; end
  def self.size; @@size; end
  def self.title; @@title; end
  def self.in_sidebarBox_div?; @@in_sidebarBox_div; end
end

class Out::Quick
  alias flickr_old_sidebar_list_erb sidebar_list_erb
  def sidebar_list_erb
    l = flickr_old_sidebar_list_erb
    if l.last == "sidebar_hobix"
      l[0 ... (l.length - 1)] + ['sidebar_flickr', 'sidebar_hobix']
    else
      l + ['sidebar_flickr']
    end
  end

  def sidebar_flickr_erb
    (FlickrPlugin.in_sidebarBox_div? ? %{<div class="sidebarBox">} : "") +
      (FlickrPlugin.title ? %{<h2 class="sidebarTitle">#{FlickrPlugin.title}</h2>} : "") +
      %{
<!-- Start of Flickr Badge -->
<!-- Start of Flickr Badge -->
<style type="text/css">
#flickr_badge_source_txt {padding:0; font: 11px Arial, Helvetica, Sans serif; color:#666666;}
#flickr_badge_icon {display:block !important; margin:0 !important; border: 1px solid rgb(0, 0, 0) !important;}
#flickr_icon_td {padding:0 5px 0 0 !important;}
.flickr_badge_image {text-align:center !important;}
.flickr_badge_image img {border: 1px solid black !important;}
#flickr_www {display:block; padding:0 10px 0 10px !important; font: 11px Arial, Helvetica, Sans serif !important; color:#3993ff !important;}
#flickr_badge_uber_wrapper a:hover,
#flickr_badge_uber_wrapper a:link,
#flickr_badge_uber_wrapper a:active,
#flickr_badge_uber_wrapper a:visited {text-decoration:none !important; background:inherit !important;color:#3993ff;}
#flickr_badge_wrapper {border: solid 1px #000000}
#flickr_badge_source {padding:0 !important; font: 11px Arial, Helvetica, Sans serif !important; color:#666666 !important;}
</style>
<table id="flickr_badge_uber_wrapper" cellpadding="0" cellspacing="10" border="0"><tr><td><a href="http://www.flickr.com" id="flickr_www">www.<strong style="color:#3993ff">flick<span style="color:#ff1c92">r</span></strong>.com</a><table cellpadding="0" cellspacing="10" border="0" id="flickr_badge_wrapper">
<script type="text/javascript" src="http://www.flickr.com/badge_code_v2.gne?count=#{FlickrPlugin.num}&display=latest&size=#{FlickrPlugin.size}&layout=v&source=user&user=#{FlickrPlugin.userid}"></script>
</table>
</td></tr></table>
<!-- End of Flickr Badge -->
    } +
    (FlickrPlugin.in_sidebarBox_div? ? "</div>" : "")
  end
end

end
