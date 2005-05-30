## bloglines.rb -- Hobix Bloglines plugin
##
## Displays your Bloglines subscriptions on the sidebar. If you use
## Bloglines, this is a nice way to automatically build a blogroll.
## This is based on the instructions at
## http://www.bloglines.com/help/share.
##
## Bloglines does all the work here. This plugin just generates a
## Javascript URL.
##
## USAGE:
##
## 1) In hobix.yaml (e.g. by running 'hobix edit <blogname>'), in the
##    'required' block, append as follows:
##
## required:
##   - hobix/plugin/bloglines:
##       userid: <your bloglines userid>
##
##    You can also specify any of the following arguments:
##
## required:
##   - hobix/plugin/bloglines:
##       userid: <your bloglines userid>
##       folder: <bloglines folder to export (default all)>
##       title: <title (default "Blogroll"), or nil for none>
##       in-sidebarBox-div: <true or false (default true)>
##
## NOTES:
##
## 1) If you redefine 'sidebar_list' in hobix.yaml, you'll need to
##    explicitly add a 'sidebar_bloglines' item.

module Hobix

## we just keep parameters from hobix.yaml here
class BloglinesPlugin < BasePlugin
  def initialize(weblog, params = {})
    raise %{the bloglines plugin needs a "userid" parameter. see hobix/plugin/bloglines.rb for details} unless params.member? "userid"
    @@userid = params["userid"]
    @@folder = params["folder"]
    @@title = params["title"] || "Blogroll"
    @@in_sidebarBox_div = lambda { |x| (x.nil? ? true : x) }[params["in-sidebarBox-div"]]
  end

  def self.userid; @@userid; end
  def self.folder; @@folder; end
  def self.title; @@title; end
  def self.in_sidebarBox_div?; @@in_sidebarBox_div; end
end

class Out::Quick
  alias bloglines_old_sidebar_list_erb sidebar_list_erb
  def sidebar_list_erb
    l = bloglines_old_sidebar_list_erb
    if l.last == "sidebar_hobix"
      l[0 ... (l.length - 1)] + ['sidebar_bloglines', 'sidebar_hobix']
    else
      l + ['sidebar_bloglines']
    end
  end

  def sidebar_bloglines_erb
    (BloglinesPlugin.in_sidebarBox_div? ? %{<div class="sidebarBox">} : "") +
      (BloglinesPlugin.title ? %{<h2 class="sidebarTitle">#{BloglinesPlugin.title}</h2>} : "") +
      %{<script language="javascript" type="text/javascript" src="http://rpc.bloglines.com/blogroll?id=#{BloglinesPlugin.userid}} +
      (BloglinesPlugin.folder ? "&folder=#{BloglinesPlugin.folder}" : "") +
      %{"></script>} +
      (BloglinesPlugin.in_sidebarBox_div? ? "</div>" : "")
  end
end

end
