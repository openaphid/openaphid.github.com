module Jekyll
  class SlideShare < Liquid::Tag

    def initialize(name, id, tokens)
      super
      @id = id
    end

    def render(context)
      %(<iframe src="http://www.slideshare.net/slideshow/embed_code/#{@id}" width="595" height="446" frameborder="0" marginwidth="0" marginheight="0" scrolling="no" style="border:1px solid #CCC;border-width:1px 1px 0;margin-bottom:5px" allowfullscreen></iframe> )
    end
  end
end

Liquid::Template.register_tag('slideshare', Jekyll::SlideShare)
