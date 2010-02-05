# Require an API key
before do
  unless ApiKey.allowed? api_key
    halt 403, 'API key required, you can obtain one from http://services.sunlightlabs.com/accounts/register/'
  end
end

# If we delivered a request, log the hit for analytics purposes
after do
  if params[:captures]
    attributes = {
      :sections => (params[:sections] || '').split(','),
      :method => params[:captures][0],
      :format => params[:captures][1],
      :key => api_key
    }
    begin
      Hit.create! attributes
    rescue
      Report.failure "Drumbone", "Error logging a hit, attributes and URL attached.", {:hit => attributes, :url => request.env['REQUEST_URI']}
    end
  end
end

# Accept the API key through the query string or the x-apikey header
def api_key
  params[:apikey] || request.env['HTTP_X_APIKEY']
end