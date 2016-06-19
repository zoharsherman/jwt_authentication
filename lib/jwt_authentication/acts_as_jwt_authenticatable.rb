require 'active_support/concern'
require 'jwt_authentication/token_generator'

module JwtAuthentication
  module ActsAsJwtAuthenticatable
    extend ::ActiveSupport::Concern

    included do
      private :generate_authentication_token
      private :token_suitable?
      private :token_generator
      private :token_expires_and_data
    end

    def ensure_authentication_token
      if authentication_token.blank?
        self.authentication_token = generate_authentication_token(token_generator)
      end
    end

    def generate_authentication_token(token_generator)
      loop do
        token = token_generator.generate_token
        break token if token_suitable?(token)
      end
    end

    def regenerate_authentication_token!
      self.update_column :authentication_token, generate_authentication_token(token_generator)
    end

    def token_suitable?(token)
      self.class.where(authentication_token: token).count == 0
    end

    def token_generator
      @token_generator ||= TokenGenerator.new
    end

    def token_expires_and_data(remember = false)
      data = self.class.jwt_key_fields.inject({}) { |hash, field| hash[field] = self.send field; hash }

      [Time.now + jwt_session_duration(remember), data]
    end

    def jwt_token_and_expires(remember = false)
      expires, data = token_expires_and_data(remember)
      payload = {exp: expires.to_i, self.class.name.underscore => data}

      [JWT.encode(payload, self.authentication_token), expires]
    end

    def jwt_token(remember = false)
      jwt_token_and_expires(remember).first
    end

    def jwt_session_duration(remember = false)
      remember ? self.class.jwt_timeout_remember_me : self.class.jwt_timeout
    end

    module ClassMethods
      def acts_as_jwt_authenticatable(options = {})
        mattr_accessor :jwt_timeout_remember_me
        mattr_accessor :jwt_timeout
        mattr_accessor :jwt_key_fields
        before_save :ensure_authentication_token
        self.jwt_timeout_remember_me = options[:timeout_remember_me] || JwtAuthentication.jwt_timeout_remember_me
        self.jwt_timeout = options[:timeout] || JwtAuthentication.jwt_timeout
        self.jwt_key_fields = options[:key_fields] || JwtAuthentication.key_fields
      end
    end
  end
end
