# frozen_string_literal: true

class Admin::Search::UsersController < Admin::BaseController
  include Admin::ListPaginatedUsers

  def index
    set_meta_tag(title: "Search for #{params[:query].present? ? params[:query].strip : "users"}")
    @users = User.admin_search(params[:query]).order(created_at: :desc)

    list_paginated_users(users: @users, template: "Admin/Search/Users/Index", single_result_redirect_path: ->(user) { admin_user_path(user.external_id) })
  rescue ActiveRecord::StatementTimeout
    respond_to do |format|
      format.html do
        flash[:alert] = "Search timed out. Try a more specific query."
        redirect_to admin_path
      end
      format.json { render json: { error: "Search timed out. Try a more specific query." }, status: :request_timeout }
    end
  end
end
