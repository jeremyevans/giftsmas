class User < Sequel::Model
  one_to_many :events, :order=>:name

  def password=(new_password)
    self.password_hash = BCrypt::Password.create(new_password, :cost=>BCRYPT_COST)
  end
end
