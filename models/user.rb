class User < Sequel::Model
  one_to_many :events, :order=>:name

  def password=(new_password)
    self.password_hash = BCrypt::Password.create(new_password, :cost=>BCRYPT_COST)
  end
end

# Table: users
# Columns:
#  id            | integer | PRIMARY KEY DEFAULT nextval('users_id_seq'::regclass)
#  name          | text    | NOT NULL
#  password_hash | text    | NOT NULL
# Indexes:
#  users_pkey       | PRIMARY KEY btree (id)
#  users_name_index | UNIQUE btree (name)
# Check constraints:
#  users_name_check | (char_length(name) > 0)
# Referenced By:
#  events | events_user_id_fkey | (user_id) REFERENCES users(id)
#  gifts  | gifts_user_id_fkey  | (user_id) REFERENCES users(id)
#  people | people_user_id_fkey | (user_id) REFERENCES users(id)
