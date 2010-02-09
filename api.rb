# Require an API key
before do
  if request.path_info =~ /^\/api\//
    halt 403, 'Bad signature' unless verify params
  else
    unless ApiKey.allowed? api_key
      halt 403, 'API key required, you can obtain one from http://services.sunlightlabs.com/accounts/register/'
    end
  end
end

# If we delivered a request, log the hit for analytics purposes
after do
  unless request.path_info =~ /^\/api\//
    if params[:captures]
      Hit.create(
        :sections => (params[:sections] || '').split(','),
        :method => params[:captures][0],
        :format => params[:captures][1],
        :key => api_key
      )
    end
  end
end

post '/api/create_key/' do
  begin
    ApiKey.create! :key => params[:key],
        :email => params[:email],
        :status => params[:status]
  rescue
    halt 403, "Could not create key, errors: #{key.errors.full_messages.join ', '}"
  end
end

post '/api/update_key/' do
  if key = ApiKey.first(:conditions => {:key => params[:key]})
    begin
      key.update_attributes! :email => params[:email], :status => params[:status]
    rescue
      halt 403, "Could not update key, errors: #{key.errors.full_messages.join ', '}"
    end
  else
    halt 404, 'Could not locate api key by the given key'
  end
end

post '/api/update_key_by_email/' do
  if key = ApiKey.first(:conditions => {:email => params[:email]})
    begin
      key.update_attributes! :key => params[:key], :status => params[:status]
    rescue
      halt 403, "Could not update key, errors: #{key.errors.full_messages.join ', '}"
    end
  else
    halt 404, 'Could not locate api key by the given email'
  end
end

def verify(params)
  return false unless params[:key] and params[:email] and params[:status]
  return false unless params[:api] == config[:services][:api_name]
  true
end

# Accept the API key through the query string or the x-apikey header
def api_key
  params[:apikey] || request.env['HTTP_X_APIKEY']
end


class ApiKey
  include MongoMapper::Document
  
  key :key, String, :required => true, :unique => true, :index => true
  key :email, String, :required => true, :unique => true, :index => true
  key :status, String, :required => true, :index => true
  timestamps!
  
  def self.allowed?(key)
    ApiKey.exists? :key => key, :status => 'A'
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