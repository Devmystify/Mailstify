class SubscribersController < ApplicationController
  before_action :set_subscriber, only: :destroy

  # GET /subscribers or /subscribers.json
  def index
    @subscribers = Subscriber.all
  end

  # GET /subscribers/1 or /subscribers/1.json
  def show
  end

  # GET /subscribers/new
  def new
    @subscriber = Subscriber.new
  end

  # GET /subscribers/1/edit
  def edit
  end

  # POST /subscribers or /subscribers.json
  def create
    list = Current.user.lists.find(subscriber_params[:list_id])
    @subscriber = list.subscribers.new(subscriber_params.except(:list_id))

    respond_to do |format|
      if @subscriber.save
        streams = [
          turbo_stream.prepend(
            helpers.dom_id(list, :subscribers),
            @subscriber
          ),
          turbo_stream.replace(
            "new_subscriber_form",
            partial: "subscribers/form",
            locals: { list: list, subscriber: Subscriber.new }
          ),
          turbo_stream.update("subscriber-count", list.subscribers.count)
        ]

        # If this is the FIRST subscriber, remove the empty-state row
        if list.subscribers.count == 1
          streams << turbo_stream.remove(helpers.dom_id(list, :empty_state))
        end

        format.turbo_stream { render turbo_stream: streams }
        format.html { redirect_to list_url(list), notice: "Subscriber was successfully created." }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "new_subscriber_form",
            partial: "subscribers/form",
            locals: { list: list, subscriber: @subscriber }
          ), status: :unprocessable_entity
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to lists_url, alert: "List not found or unauthorized."
  end

  # PATCH/PUT /subscribers/1 or /subscribers/1.json
  def update
    respond_to do |format|
      if @subscriber.update(subscriber_params)
        format.html { redirect_to @subscriber, notice: "Subscriber was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @subscriber }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @subscriber.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /subscribers/1 or /subscribers/1.json
  def destroy
    @list = @subscriber.list
    @subscriber.destroy

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(@subscriber),
          turbo_stream.update("subscriber-count", @list.subscribers.count),
          (@list.subscribers.empty? ?
            turbo_stream.append(
              helpers.dom_id(@list, :subscribers),
              partial: "subscribers/empty_state",
              locals: { list: @list }
            ) : nil)
        ].compact
      end
      format.html { redirect_to list_url(@list), notice: "Subscriber was successfully removed." }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_subscriber
      @subscriber = Subscriber.joins(:list)
        .where(lists: { user_id: Current.user.id })
        .find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to lists_url, alert: "Subscriber not found or unauthorized."
    end

    # Only allow a list of trusted parameters through.
    def subscriber_params
      params.expect(subscriber: [ :email, :name, :list_id ])
    end
end
