class Legislator
  include MongoMapper::Document
  
  key :bioguide_id, String, :required => true
  key :active, Boolean, :required => true
  key :chamber, String, :required => true
  
  timestamps!
  
  def self.active
    all :conditions => {:active => true}
  end
  
  private
  
  def self.chamber_for(api_legislator)
    {
      'Rep' => 'House',
      'Sen' => 'Senate',
      'Del' => 'House',
      'Com' => 'House'
    }[api_legislator.title]
  end
end