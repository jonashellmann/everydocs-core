class SearchController < ApplicationController

  #GET /search/suggestions/:text
  def suggestions
    @encoded_html = Nokogiri::HTML.parse params[:text]
    @text = @encoded_html.text
    @result = current_user.documents.select("title, count(*) as count").where("title LIKE ?", "%#{@text}%").group("title").order(title: :asc)
   
    @json = ''
    @result.each do |r| 
      @json = @json + '{title: ' + r.title + ', count: ' + r.count.to_s + '},'
    end
    @json = '[' + @json + ']'
    
    render json: @json
  end

end
