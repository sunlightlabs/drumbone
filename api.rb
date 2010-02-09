# Require an API key
before do
  unless ApiKey.allowed? api_key
    halt 403, 'API key required, you can obtain one from http://services.sunlightlabs.com/accounts/register/'
  end
end

# If we delivered a request, log the hit for analytics purposes
after do
  if params[:captures]
    Hit.create(
      :sections => (params[:sections] || '').split(','),
      :method => params[:captures][0],
      :format => params[:captures][1],
      :key => api_key
    )
  end
end

# Accept the API key through the query string or the x-apikey header
def api_key
  params[:apikey] || request.env['HTTP_X_APIKEY']
end


class ApiKey
  include MongoMapper::Document
  
  key :key, String, :required => true, :index => true
  timestamps!
  
  def self.allowed?(key)
    ApiKey.exists? :key => key
  end
end

class Hit
  include MongoMapper::Document
  
  key :method, String, :required => true
  key :key, String, :required => true
  key :sections, Array
  key :format, String
  timestamps!
end