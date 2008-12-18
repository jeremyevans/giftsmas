class User < Sequel::Model
  one_to_many :events, :order=>:name

  def self.login_user_id(username, password)
    return unless username && password
    return unless u = filter(:name=>username).first
    return unless u.password == ::Digest::SHA1.new.update(u.salt).update(password).hexdigest
    u.id
  end
  
  def password=(pass)
    self.salt = `openssl rand -hex 20`
    self[:password] = ::Digest::SHA1.new.update(salt).update(pass).hexdigest
  end
end
