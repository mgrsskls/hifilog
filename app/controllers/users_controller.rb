class UsersController < ApplicationController
  def index
    @users_by_products = ActiveRecord::Base.connection.execute("
      SELECT users.id, users.user_name, users.profile_visibility, users.created_at, COUNT(*)
      FROM users
      LEFT JOIN versions
      ON users.id = CAST(versions.whodunnit as bigint)
      GROUP BY users.id
      ORDER BY count DESC
    ")
  end
end
