Sequel.migration do
  up do
    drop_column(:users, :password)
    drop_column(:users, :salt)

    add_column(:users, :password_hash, :text)
    # Bcrypt hash of: demo by default
    from(:users).update(:password_hash=>"$2a$04$X5QQ9b3cKu8ReRsz8HM8W.jhRX2XJM4wB.n2xjgU9I6b5RZHR0Z4W")
    alter_table(:users){set_column_allow_null :password_hash, false}
  end
  down do
    drop_column(:users, :password_hash)
    add_column(:users, :salt, :text)
    add_column(:users, :password, :text)
  end
end
