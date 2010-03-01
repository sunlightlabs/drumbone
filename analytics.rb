require 'cgi'
require 'hmac-sha1'

# Accept the API key through the query string or the x-apikey header
def api_key
  params[:apikey] || request.env['HTTP_X_APIKEY']
end

before do
  # verify signature and parameters
  if request.path_info =~ /^\/analytics\//
    unless SunlightServices.verify params, config[:services][:shared_secret], config[:services][:api_name]
      halt 403, 'Bad signature' 
    end
  else
    # Require an API key
    unless ApiKey.allowed? api_key
      halt 403, 'API key required, you can obtain one from http://services.sunlightlabs.com/accounts/register/'
    end
  end
end

after do
  unless request.path_info =~ /^\/api\//
    # log hits
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

post '/analytics/create_key/' do
  begin
    ApiKey.create! :key => params[:key],
        :email => params[:email],
        :status => params[:status]
  rescue
    halt 403, "Could not create key, duplicate key or email"
  end
end

post '/analytics/update_key/' do
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

post '/analytics/update_key_by_email/' do
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

class SunlightServices
  
  def self.report(key, endpoint, calls, date, api, shared_secret)
    url = URI.parse "http://services.sunlightlabs.com/analytics/report_calls/"
    
    params = {:key => key, :endpoint => endpoint, :date => date, :api => api, :calls => calls}
    signature = signature_for params, shared_secret
                              
    Net::HTTP.post_form url, params.merge(:signature => signature)
  end
  
  def self.verify(params, shared_secret, api_name)
    return false unless params[:key] and params[:email] and params[:status]
    return false unless params[:api] == api_name
    
    given_signature = params.delete 'signature'
    signature = signature_for params, shared_secret
    
    signature == given_signature
  end

  def self.signature_for(params, shared_secret)
    HMAC::SHA1.hexdigest shared_secret, signature_string(params)
  end

  def self.signature_string(params)
    params.keys.map(&:to_s).sort.map do |key|
      "#{key}=#{CGI.escape((params[key] || params[key.to_sym]).to_s)}"
    end.join '&'
  end
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