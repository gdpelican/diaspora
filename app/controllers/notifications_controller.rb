#   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

class NotificationsController < ApplicationController
  before_action :authenticate_user!

  layout ->(c) { request.format == :mobile ? "application" : "with_header_with_footer" }
  use_bootstrap_for :index

  def update
    if note = current_user.notifications.find_by_id(params[:id])
      note.set_read_state(params[:set_unread] != "true")
      response = { guid: note.id, unread: note.unread }
    end

    respond_to do |format|
      format.json { render json: response || {} }
    end
  end

  def index
    @notifications = paginated_collection current_user.notifications
                                                      .includes(:target, actors: :profile)
                                                      .by_type(params[:type])
                                                      .unread_only(params[:show] == 'unread')
                                                      .order(:created_at)
    
    @unread_notification_count          = current_user.unread_notifications.count
    @grouped_unread_notification_counts = Notification.group_by_type(current_user.unread_notifications)
    @group_days                         = @notifications.group_by(&:day_created)

    @notifications.each do |n|
      n.note_html = render_to_string( :partial => 'notify_popup_item', :locals => { :n => n } ) # ew!
    end

    respond_to do |format|
      format.html
      format.xml { render :xml => @notifications.to_xml }
      format.json { render :json => @notifications.to_json }
    end

  end

  def read_all
    current_user.unread_notifications.by_type(params[:type]).update_all(unread: false)
    
    respond_to do |format|
      format.html { redirect_to path_after_read_all }
      format.mobile { redirect_to path_after_read_all }
      format.xml { render :xml => {}.to_xml }
      format.json { render :json => {}.to_json }
    end

  end

  private

  def paginated_collection(collection)
    WillPaginate::Collection.create params[:page] || 1, params[:per_page] || 25, collection.size do |pager|
      pager.replace collection.limit(pager.per_page).offset(pager.offset)
    end
  end

  def path_after_read_all
    current_user.unread_notifications.count > 0 ? notifications_path : stream_path
  end

end
