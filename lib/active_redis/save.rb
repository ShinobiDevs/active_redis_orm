module ActiveRedis
  module Save
    #TODO: add if valid?
    def save(options={})
      unless options[:validate] == false
        return false if invalid?(save_context)
      end

      if dirty?
        case save_context
        when :create
          perform_create
        when :update
          perform_update
        end
        true
      else
        false
      end
    end

    def new_record?
      !!@new_record
    end

    private

    def perform_save
      run_callbacks :save do
        Redis.current.pipelined do
          self.changes.each do |key, value|
            send("set_#{key}", value)
          end
        end
        @new_record = false
        @changed_attributes.clear
      end
    end

    def perform_update
      run_callbacks :update do
        perform_save
      end
    end

    def perform_create
      run_callbacks :create do
        #TODO: check if no object exists under that id
        @id ||= SecureRandom.uuid().delete('-')
        perform_save
      end
    end

    def save_context
      if new_record?
        :create
      else
        :update
      end
    end
  end
end