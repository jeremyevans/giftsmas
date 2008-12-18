class User < Sequel::Model
  one_to_many :events, :order=>:name

  def self.login_user_id(username, password)
    return unless username && password
    return unless u = filter(:name=>username).first
    return unless u.password == ::Digest::SHA1.new.update(u.salt).update(password).hexdigest
    u.id
  end
  
  def password=(pass)
    self.salt = new_salt
    self[:password] = ::Digest::SHA1.new.update(salt).update(pass).hexdigest
  end

  private

  def new_salt
    (0...40).map{(i = Kernel.rand(62); i += ((i < 10) ? 48 : ((i < 36) ? 55 : 61 ))).chr}.join
  end
end
