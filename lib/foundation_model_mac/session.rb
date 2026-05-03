# frozen_string_literal: true

module AppleFoundationModel
  class Session
    def initialize(instructions: nil)
      @handle = AppleFoundationModel::Native.session_create(instructions: instructions)
      @closed = false
      ObjectSpace.define_finalizer(self, self.class.finalizer(@handle))
    end

    def respond(to:)
      raise AppleFoundationModel::Error, "session is closed" if @closed
      AppleFoundationModel::Native.session_respond(@handle, to)
    end

    def close
      return if @closed
      AppleFoundationModel::Native.session_destroy(@handle)
      @closed = true
    end

    def closed?
      @closed
    end

    def self.finalizer(handle)
      proc {
        if AppleFoundationModel::Native.session_exists(handle)
          AppleFoundationModel::Native.session_destroy(handle)
        end
      }
    end
  end
end
