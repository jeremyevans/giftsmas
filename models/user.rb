class User < Sequel::Model
  one_to_many :events, :order=>:name

  def self.login_user_id(username, password)
    return unless username && password
    return unless u = filter(:name=>username).first
    return unless BCrypt::Password.new(u.password_hash) == password
    u.id
  end
  
  def password=(new_password)
    self.password_hash = BCrypt::Password.create(new_password, :cost=>BCRYPT_COST)
  end
end
